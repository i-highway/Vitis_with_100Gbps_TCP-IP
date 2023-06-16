// Copyright (c) 2023 Intellectual Highway. All rights reserved.
#include "http_server_config.hpp"
#include "http_server.hpp"
#include <iostream>

bool path_cmp(char *str1, char *str2) {
  bool ret = true;
  for (int i = 0; i < 64; i++) {
    if (str1[i] != str2[i]) {
      ret = false;
    }
  }
  return ret;
}

//Buffers responses coming from the TCP stack
void status_handler(hls::stream<appTxRsp>& txStatus,
                    hls::stream<internalAppTxRsp>& txStatusBuffer) {
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

  if (!txStatus.empty()) {
    appTxRsp resp = txStatus.read();
    txStatusBuffer.write(internalAppTxRsp(resp.sessionID, resp.error));
  }
}

void txMetaData_handler(hls::stream<appTxMeta>&	txMetaDataBuffer,
                        hls::stream<appTxMeta>& txMetaData) {
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

  if (!txMetaDataBuffer.empty()) {
    appTxMeta metaDataReq = txMetaDataBuffer.read();
    txMetaData.write(metaDataReq);
  }
}

template <int WIDTH>
void txDataBuffer_handler(hls::stream<net_axis<WIDTH>>& txDataBuffer,
                          hls::stream<ap_axiu<WIDTH, 0, 0, 0>>& txData) {
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

  if (!txDataBuffer.empty()) {
    net_axis<WIDTH> inWord = txDataBuffer.read();
    ap_axiu<WIDTH, 0, 0, 0> outWord;
    outWord.data = inWord.data;
    outWord.keep = inWord.keep;
    outWord.last = inWord.last;
    txData.write(outWord);
  }
}

template <int WIDTH>
void rxDataBuffer_handler(hls::stream<ap_axiu<WIDTH, 0, 0, 0>>& rxData,
                          hls::stream<net_axis<WIDTH>>& rxDataBuffer) {
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

  if (!rxData.empty()) {
    ap_axiu<WIDTH, 0, 0, 0> inWord = rxData.read();
    net_axis<WIDTH> outWord;
    outWord.data = inWord.data;
    outWord.keep = inWord.keep;
    outWord.last = inWord.last;
    rxDataBuffer.write(outWord);
  }
}

template <int WIDTH>
void server(hls::stream<ap_uint<16>>&listenPort,
            hls::stream<bool>& listenPortStatus,
            hls::stream<appNotification>& notifications,
            hls::stream<appReadRequest>& readRequest,
            hls::stream<ap_uint<16>>& rxMetaData,
            hls::stream<net_axis<WIDTH>>& rxDataBuffer,
            hls::stream<ap_uint<16>>& closeConnection,
            hls::stream<appTxMeta>& txMetaDataBuffer,
            hls::stream<net_axis<WIDTH>>& txDataBuffer,
            hls::stream<internalAppTxRsp>& txStatus,
            ap_uint<1> startServer,
            ap_uint<512>* fileList,
            ap_uint<512>* fileData,
            ap_uint<32> fileNum,
            ap_uint<16> serverPort) {
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    const char RESP_OK_DATA[] = "HTTP/1.1 200 OK";
    const int RESP_OK_LEN = 15;
    const char RESP_NOT_FOUND_DATA[] = "HTTP/1.1 404 Not Found";
    const int RESP_NOT_FOUND_LEN = 22;

    enum listenFsmStateType {OPEN_PORT, WAIT_PORT_STATUS};
    static listenFsmStateType listenState = OPEN_PORT;

    enum serverFsmStateType {
      WAIT_REQ,
      PARSE_FIND_PATH,
      PARSE_PATH,
      SEARCH_FILE,
      RESP_HEADER,
      RESP_BODY_CMD,
      RESP_BODY_DATA,
      RESP_NOT_FOUND,
      COMPLETE
    };
    static serverFsmStateType serverState = WAIT_REQ;

    static ap_uint<16> sessionID;
    static uint64_t remainBytes;
    static int curTxBytes;
    static uint64_t dataWordOffset;

    static char header[256];
    static int headerPos = 0;
    static char path[64];
#pragma HLS array_partition variable=path type=complete
    static int pathStartPos = 0;
    static int pathPos = 0;
    static int fileEntryIdx = 0;

    static char filePath[8][64];
#pragma HLS array_partition variable=filePath type=complete
    static char fileMime[8][48];
    static uint64_t fileSize[8];
    static uint64_t fileOffset[8];
    static bool initedFileList = false;

    if (startServer == 0) {
      return;
    }

    if (!initedFileList) {
      for (int i = 0; i < fileNum; i++) {
        ap_uint<512> fileEntry0 = fileList[i * 2];
        ap_uint<512> fileEntry1 = fileList[i * 2 + 1];

        // init filePath
        for (int j = 0; j < 64; j++) {
          filePath[i][j] = fileEntry0(j * 8 + 7, j * 8);
        }
        // init fileMime
        for (int j = 0; j < 48; j++) {
          fileMime[i][j] = fileEntry1(j * 8 + 7, j * 8);
        }
        // init fileSize and fileOffset
        fileSize[i] = fileEntry1(511, 448);
        fileOffset[i] = fileEntry1(447, 384);
      }
    }
    initedFileList = true;

    switch (listenState) {
      case OPEN_PORT:
        listenPort.write(serverPort);
        listenState = WAIT_PORT_STATUS;
        break;
      case WAIT_PORT_STATUS:
        if (!listenPortStatus.empty()) {
          bool open = listenPortStatus.read();
          if (!open) {
            listenState = OPEN_PORT;
          }
        }
        break;
    }

    if (!notifications.empty()) {
      appNotification notification = notifications.read();
      if (notification.length != 0) {
        readRequest.write(appReadRequest(notification.sessionID, notification.length));
      }
    }

    switch (serverState) {
      case WAIT_REQ: {
        if (!rxMetaData.empty()) {
          sessionID = rxMetaData.read();
        }
        if (!rxDataBuffer.empty()) {
          net_axis<WIDTH> rxWord = rxDataBuffer.read();
          std::cout << "data=" << std::hex << rxWord.data << " keep=" << rxWord.keep << std::dec << " last=" << rxWord.last << std::endl;

          for (int i = 0; i < WIDTH / 8; i++) {
            if ((rxWord.keep >> i) & 0x1) {
              header[headerPos + i] = rxWord.data(i * 8 + 7, i * 8);
            } else {
              header[headerPos + i] = 0;
            }
          }
          headerPos += WIDTH / 8;
          if (rxWord.last == 1) {
            std::cout << "serverState: " << WAIT_REQ << "->" << PARSE_FIND_PATH << std::endl;
            serverState = PARSE_FIND_PATH;
          }
        }
        break;
      }
      case PARSE_FIND_PATH: {
        if (header[pathStartPos] == ' ') {
          std::cout << "serverState: " << PARSE_FIND_PATH << "->" << PARSE_PATH << std::endl;
          serverState = PARSE_PATH;
        }
        pathStartPos++;
        break;
      }
      case PARSE_PATH: {
        if (header[pathStartPos + pathPos] == ' ') {
          path[pathPos] = 0;
          std::cout << "serverState: " << PARSE_PATH << "->" << SEARCH_FILE << std::endl;
          serverState = SEARCH_FILE;
        } else {
          path[pathPos] = header[pathStartPos + pathPos];
          pathPos++;
        }
        break;
      }
      case SEARCH_FILE: {
        //if (strcmp(path, filePath[fileEntryIdx]) == 0) {
        if (path_cmp(path, filePath[fileEntryIdx])) {
          txMetaDataBuffer.write(appTxMeta(sessionID, WIDTH / 8));
          remainBytes = fileSize[fileEntryIdx];
          dataWordOffset = fileOffset[fileEntryIdx] / 64;
          std::cout << "serverState: " << SEARCH_FILE << "->" << RESP_HEADER << std::endl;
          serverState = RESP_HEADER;
        } else if (fileEntryIdx == fileNum - 1) {
          txMetaDataBuffer.write(appTxMeta(sessionID, WIDTH / 8));
          std::cout << "serverState: " << SEARCH_FILE << "->" << RESP_NOT_FOUND << std::endl;
          serverState = RESP_NOT_FOUND;
        } else {
          fileEntryIdx++;
        }
        break;
      }
      case RESP_HEADER: {
        if (!txStatus.empty()) {
          internalAppTxRsp resp = txStatus.read();
          if (resp.error == 0) {
            // send header
            net_axis<WIDTH> headerWord;
            for (int i = 0; i < WIDTH / 8; i++) {
              headerWord.data(i * 8 + 7, i * 8) = ' ';
              headerWord.keep[i] = 1;
            }
            for (int i = 0; i < RESP_OK_LEN; i++) {
              headerWord.data(i * 8 + 7, i * 8) = RESP_OK_DATA[i];
            }
            headerWord.data(WIDTH - 25, WIDTH - 32) = '\r';
            headerWord.data(WIDTH - 17, WIDTH - 24) = '\n';
            headerWord.data(WIDTH - 9, WIDTH - 16) = '\r';
            headerWord.data(WIDTH - 1, WIDTH - 8) = '\n';
            headerWord.last = 1;
            txDataBuffer.write(headerWord);

            // request send body
            curTxBytes = remainBytes > (WIDTH / 8 * 22) ? (WIDTH / 8 * 22) : remainBytes;
            txMetaDataBuffer.write(appTxMeta(sessionID, curTxBytes));

            std::cout << "serverState: " << RESP_HEADER << "->" << RESP_BODY_CMD << std::endl;
            serverState = RESP_BODY_CMD;
          } else {
            // retry to request send header
            txMetaDataBuffer.write(appTxMeta(sessionID, WIDTH / 8));
          }
        }
        break;
      }
      case RESP_BODY_CMD: {
        std::cout << "serverState=RESP_BODY" << std::endl;
        if (!txStatus.empty()) {
          internalAppTxRsp resp = txStatus.read();
          if (resp.error == 0) {
            remainBytes -= curTxBytes;
            std::cout << "serverState: " << RESP_BODY_CMD << "->" << RESP_BODY_DATA << std::endl;
            serverState = RESP_BODY_DATA;            
          } else {
            // retry
            curTxBytes = remainBytes > (WIDTH / 8 * 22) ? (WIDTH / 8 * 22) : remainBytes;
            txMetaDataBuffer.write(appTxMeta(sessionID, curTxBytes));
          }
        }
        break;
      }
      case RESP_BODY_DATA: {
        if (curTxBytes > 0) {
          net_axis<WIDTH> bodyWord;
          int bytes = curTxBytes > (WIDTH / 8) ? (WIDTH / 8) : curTxBytes;
          std::cout << "dataWordOffset=" << std::hex << dataWordOffset << std::dec << std::endl;
          bodyWord.data = fileData[dataWordOffset];
          dataWordOffset++;
          for (int i = 0; i < WIDTH / 8; i++) {
            if (i < bytes) {
              bodyWord.keep[i] = 1;
            } else {
              bodyWord.keep[i] = 0;
            }
          }
          bodyWord.last = curTxBytes <= (WIDTH / 8);
          txDataBuffer.write(bodyWord);
          curTxBytes -= bytes;
        } else if (remainBytes > 0) {
          curTxBytes = remainBytes > (WIDTH / 8 * 22) ? (WIDTH / 8 * 22) : remainBytes;
          txMetaDataBuffer.write(appTxMeta(sessionID, curTxBytes));
          std::cout << "serverState: " << RESP_BODY_DATA << "->" << RESP_BODY_CMD << std::endl;
          serverState = RESP_BODY_CMD;
        } else {
          std::cout << "serverState: " << RESP_BODY_DATA << "->" << COMPLETE << std::endl;
          serverState = COMPLETE;
        }
        break;
      }
      case RESP_NOT_FOUND: {
        if (!txStatus.empty()) {
          internalAppTxRsp resp = txStatus.read();
          if (resp.error == 0) {
            net_axis<WIDTH> headerWord;
            for (int i = 0; i < WIDTH / 8; i++) {
              headerWord.data(i * 8 + 7, i * 8) = ' ';
              headerWord.keep[i] = 1;
            }
            for (int i = 0; i < RESP_NOT_FOUND_LEN; i++) {
              headerWord.data(i * 8 + 7, i * 8) = RESP_NOT_FOUND_DATA[i];
            }
            headerWord.data(WIDTH - 25, WIDTH - 32) = '\r';
            headerWord.data(WIDTH - 17, WIDTH - 24) = '\n';
            headerWord.data(WIDTH - 9, WIDTH - 16) = '\r';
            headerWord.data(WIDTH - 1, WIDTH - 8) = '\n';
            headerWord.last = 1;
            txDataBuffer.write(headerWord);
            std::cout << "serverState: " << RESP_NOT_FOUND << "->" << COMPLETE << std::endl;
            serverState = COMPLETE;
          } else {
            // retry to send header
            txMetaDataBuffer.write(appTxMeta(sessionID, WIDTH / 8));
          }
        }
        break;
      }
      case COMPLETE: {
        headerPos = 0;
        pathStartPos = 0;
        pathPos = 0;
        for (int i = 0; i < 64; i++) {
          path[i] = 0;
        }
        fileEntryIdx = 0;
        closeConnection.write(sessionID);
        std::cout << "serverState: " << COMPLETE << "->" << WAIT_REQ << std::endl;
        serverState = WAIT_REQ;
        break;
      }
    }
}

void http_server(hls::stream<ap_uint<16>>& listenPort,
                 hls::stream<bool>& listenPortStatus,
                 hls::stream<appNotification>& notifications,
                 hls::stream<appReadRequest>& readRequest,
                 hls::stream<ap_uint<16>>& rxMetaData,
                 hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>>& rxData,
                 hls::stream<ap_uint<16>>& closeConnection,
                 hls::stream<appTxMeta>& txMetaData,
                 hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>>& txData,
                 hls::stream<appTxRsp>& txStatus,
                 ap_uint<1> startServer,
                 ap_uint<512>* fileList,
                 ap_uint<512>* fileData,
                 ap_uint<32> fileNum,
                 ap_uint<16> serverPort) {
#pragma HLS DATAFLOW disable_start_propagation
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS INTERFACE axis register port=listenPort name=m_axis_listen_port
#pragma HLS INTERFACE axis register port=listenPortStatus name=s_axis_listen_port_status

#pragma HLS INTERFACE axis register port=notifications name=s_axis_notifications
#pragma HLS INTERFACE axis register port=readRequest name=m_axis_read_package
#pragma HLS aggregate compact=bit variable=notifications
#pragma HLS aggregate compact=bit variable=readRequest

#pragma HLS INTERFACE axis register port=rxMetaData name=s_axis_rx_metadata
#pragma HLS INTERFACE axis register port=rxData name=s_axis_rx_data

#pragma HLS INTERFACE axis register port=closeConnection name=m_axis_close_connection

#pragma HLS INTERFACE axis register port=txMetaData name=m_axis_tx_metadata
#pragma HLS INTERFACE axis register port=txData name=m_axis_tx_data
#pragma HLS INTERFACE axis register port=txStatus name=s_axis_tx_status
#pragma HLS aggregate compact=bit variable=txMetaData
#pragma HLS aggregate compact=bit variable=txStatus

#pragma HLS INTERFACE ap_none register port=startServer

#pragma HLS INTERFACE mode=m_axi port=fileList offset=direct bundle=gmem depth=0x80000
#pragma HLS INTERFACE mode=m_axi port=fileData offset=direct bundle=gmem depth=0x80000
#pragma HLS INTERFACE ap_none register port=fileNum

#pragma HLS INTERFACE ap_none register port=serverPort

  //This is required to buffer up to 1024 reponses => supporting up to 1024 connections
  static hls::stream<internalAppTxRsp> txStatusBuffer("txStatusBuffer");
#pragma HLS STREAM variable=txStatusBuffer depth=512
  
  //This is required to buffer up to 512 reponses => supporting up to 512 connections
  static hls::stream<openStatus> openConStatusBuffer("openConStatusBuffer");
#pragma HLS STREAM variable=openConStatusBuffer depth=512
  
  //This is required to buffer up to 512 tx_meta_data => supporting up to 512 connections
  static hls::stream<appTxMeta> txMetaDataBuffer("txMetaDataBuffer");
#pragma HLS STREAM variable=txMetaDataBuffer depth=512
  
  //This is required to buffer up to MAX_SESSIONS txData 
  static hls::stream<net_axis<DATA_WIDTH>> txDataBuffer("txDataBuffer");
#pragma HLS STREAM variable=txDataBuffer depth=512
  
  //This is required to buffer up to MAX_SESSIONS txData 
  static hls::stream<net_axis<DATA_WIDTH>> rxDataBuffer("rxDataBuffer");
#pragma HLS STREAM variable=rxDataBuffer depth=512

  status_handler(txStatus, txStatusBuffer);
  txMetaData_handler(txMetaDataBuffer, txMetaData);
  txDataBuffer_handler<DATA_WIDTH>(txDataBuffer, txData);
  rxDataBuffer_handler<DATA_WIDTH>(rxData, rxDataBuffer);

  /*
   * Server
   */
  server<DATA_WIDTH>(listenPort,
                     listenPortStatus,
                     notifications,
                     readRequest,
                     rxMetaData,
                     rxDataBuffer,
                     closeConnection,
                     txMetaDataBuffer,
                     txDataBuffer,
                     txStatusBuffer,
                     startServer,
                     fileList,
                     fileData,
                     fileNum,
                     serverPort);
}
