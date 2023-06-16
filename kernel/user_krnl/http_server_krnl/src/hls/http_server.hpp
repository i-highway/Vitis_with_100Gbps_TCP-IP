// Copyright (c) 2023 Intellectual Highway. All rights reserved.
#pragma once

#include "http_server_config.hpp"
#include "../../../../common/include/axi_utils.hpp"
#include "../../../../common/include/packet.hpp"
#include "../../../../common/include/toe.hpp"

struct internalAppTxRsp {
  ap_uint<16> sessionID;
  ap_uint<2> error;
  internalAppTxRsp() {}
  internalAppTxRsp(ap_uint<16> id, ap_uint<2> err) : sessionID(id), error(err) {}
};

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
                 ap_uint<16> serverPort);
