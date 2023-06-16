// Copyright (c) 2023 Intellectual Highway. All rights reserved.
#include "http_server_config.hpp"
#include "http_server.hpp"
#include <iostream>

using namespace hls;

int main() {
  hls::stream<ap_uint<16>> listenPort("listenPort");
  hls::stream<bool> listenPortStatus("listenPortStatus");
  hls::stream<appNotification> notifications("notifications");
  hls::stream<appReadRequest> readRequest("readRequest");
  hls::stream<ap_uint<16>> rxMetaData("rxMetaData");
  hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> rxData("rxData");
  hls::stream<ap_uint<16>> closeConnection("closeConnection");
  hls::stream<appTxMeta> txMetaData("txMetaData");
  hls::stream<ap_axiu<DATA_WIDTH, 0, 0, 0>> txData("txData");
  hls::stream<appTxRsp> txStatus("txStatus");

  ap_uint<1> startServer = 0;

  const int FILE_NUM = 4;
  ap_uint<512> fileList[FILE_NUM];
  ap_uint<32> fileNum = FILE_NUM;
  ap_uint<16> serverPort = 8080;

  // init fileList
  char filePath[FILE_NUM][64] = {
    "/file1",
    "/file2.jpg",
    "/file3.mp4",
    "/file4.html"
  };
  char fileMime[FILE_NUM][48] = {
    "text/plain",
    "image/jpeg",
    "video/mp4",
    "text/html"
  };
  uint64_t fileSize[FILE_NUM] = {
    100,
    200,
    30000,
    1000
  };
  uint64_t fileOffset[FILE_NUM] = {
    0,
    128,
    384,
    30400
  };
  for (int i = 0; i < fileNum; i++) {
    for (int j = 0; j < 64; j++) {
      fileList[i * 2](j * 8 + 7, j * 8) = filePath[i][j];
    }
    for (int j = 0; j < 48; j++) {
      fileList[i * 2 + 1](j * 8 + 7, j * 8) = fileMime[i][j];
    }
    fileList[i * 2 + 1](511, 448) = fileSize[i];
    fileList[i * 2 + 1](447, 384) = fileOffset[i];
    std::cout << "fileList[0]=" << std::hex << fileList[i * 2] << std::dec << std::endl;
    std::cout << "fileList[1]=" << std::hex << fileList[i * 2 + 1] << std::dec << std::endl;
  }
  int totalFileSize = fileOffset[fileNum - 1] + fileSize[fileNum - 1];
  ap_uint<512> *fileData = new ap_uint<512>[totalFileSize / 64 + 1];
  uint8_t fileDataVal = '0';
  for (int i = 0; i < totalFileSize; i++) {
    int wordIdx = i / 64;
    int byteIdx = i % 64;
    fileData[wordIdx](byteIdx * 8 + 7, byteIdx * 8) = fileDataVal;
    if (fileDataVal == '9') {
      fileDataVal = '0';
    } else {
      fileDataVal++;
    }
  }
  std::cout << "fileData=" << fileData << std::endl;
  std::cout << "fileData[0]=" << std::hex << fileData[0] << std::dec << std::endl;
  std::cout << "fileData[1]=" << std::hex << fileData[1] << std::dec << std::endl;

  int count = 0;
  // not start
  for (int i = 0; i < 10; i++) {
    http_server(listenPort,
                listenPortStatus,
                notifications,
                readRequest,
                rxMetaData,
                rxData,
                closeConnection,
                txMetaData,
                txData,
                txStatus,
                startServer,
                fileList,
                fileData,
                fileNum,
                serverPort);
    count++;

    if (!listenPort.empty()) {
      std::cout << "expect not start" << std::endl;
      return 1;
    }
  }

  startServer = 1;

  // listen
  for (int i = 0; i < 10; i++) {
    http_server(listenPort,
                listenPortStatus,
                notifications,
                readRequest,
                rxMetaData,
                rxData,
                closeConnection,
                txMetaData,
                txData,
                txStatus,
                startServer,
                fileList,
                fileData,
                fileNum,
                serverPort);
    count++;
  
    if (!listenPort.empty()) {
      ap_uint<16> port = listenPort.read();
      std::cout << "count=" << count << " Port " << port << " openend." << std::endl;
      if (port == 8080) {
        listenPortStatus.write(true);
        break;
      } else {
        std::cout << "not match listen port" << std::endl;
        return 1;
      }
    }
  }

  std::string getReq = "GET /file4.html HTTP/1.1\r\nHost: 192.168.0.2:8080\r\nUser-Agent: curl/7.68.0\r\nAccept: */*\r\n\r\n";

  // recv notification and read request
  appNotification notify;
  notify.sessionID = 1;
  notify.length = getReq.size();
  notify.ipAddress = 0xc0a8006f;
  notify.dstPort = 8080;
  notify.closed = false;
  notifications.write(notify);
  for (int i = 0; i < 100; i++) {
    http_server(listenPort,
                listenPortStatus,
                notifications,
                readRequest,
                rxMetaData,
                rxData,
                closeConnection,
                txMetaData,
                txData,
                txStatus,
                startServer,
                fileList,
                fileData,
                fileNum,
                serverPort);
    count++;

    if (!readRequest.empty()) {
      appReadRequest readReq = readRequest.read();
      std::cout << "count=" << count << " appReadRequest id=" << readReq.sessionID << " length=" << readReq.length << std::endl;
      if (readReq.sessionID == 1 && readReq.length == getReq.size()) {
        break;
      } else {
        std::cout << "wrong appReadRequest" << std::endl;
        return 1;
      }
    }
  }

  // response of appReadRequest
  ap_uint<16> rxMeta = 1;
  rxMetaData.write(rxMeta);

  // recv http request
  ap_axiu<DATA_WIDTH, 0, 0, 0> data;
  for (int i = 0; i < getReq.size(); i++) {
    int byte_idx = i % (DATA_WIDTH / 8);
    if (byte_idx == 0) {
      data.keep = 0;
    }

    data.data(byte_idx * 8 + 7, byte_idx * 8) = getReq[i];
    data.keep[byte_idx] = 1;

    bool last = (i == (getReq.size() - 1));
    if ((byte_idx == (DATA_WIDTH / 8 - 1)) || last) {
      if (last) {
        data.last = 1;
      } else {
        data.last = 0;
      }
      rxData.write(data);
    }
  }

  // send response
  for (int i = 0; i < 100; i++) {
    http_server(listenPort,
                listenPortStatus,
                notifications,
                readRequest,
                rxMetaData,
                rxData,
                closeConnection,
                txMetaData,
                txData,
                txStatus,
                startServer,
                fileList,
                fileData,
                fileNum,
                serverPort);
    count++;

    if (!txMetaData.empty()) {
      static bool header = true;
      appTxMeta txMeta = txMetaData.read();
      std::cout << "count=" << count << " appTxMeta id=" << txMeta.sessionID << " length=" << txMeta.length << std::endl;
      if (header) {
        if (!(txMeta.sessionID == 1 && txMeta.length == 64)) {
          std::cout << "wrong appTxMeta" << std::endl;
          return 1;
        }
        header = false;
      } else {
        if (!(txMeta.sessionID == 1 && txMeta.length == 1000)) {
          std::cout << "wrong appTxMeta" << std::endl;
          return 1;
        }
      }
      if (!(txMeta.sessionID == 1 && (txMeta.length == 64 || txMeta.length == 1000))) {
        std::cout << "wrong appTxMeta" << std::endl;
        return 1;
      }
      txStatus.write(appTxRsp(txMeta.sessionID, txMeta.length, 0xffff, 0));
    }

    if (!txData.empty()) {
      static bool header = true;
      ap_axiu<DATA_WIDTH, 0, 0, 0> txWord = txData.read();
      std::cout << "count=" << count << " txData data=" << std::hex << txWord.data << " keep=" << txWord.keep << " last=" << std::dec << txWord.last << std::endl;
    }

    if (!closeConnection.empty()) {
      ap_uint<16> closeID = closeConnection.read();
      std::cout << "count=" << count << " closeConnection id=" << closeID << std::endl;
      if (closeID != 1) {
        std::cout << "wrong closeID" << std::endl;
        return 1;
      } else {
        break;
      }
    }
  }

  std::cout << "Finished count=" << std::dec << count << std::endl;

  return 0;
}
