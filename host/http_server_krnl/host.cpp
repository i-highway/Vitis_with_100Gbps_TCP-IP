// Copyright (c) 2023 Intellectual Highway. All rights reserved.
#include <xrt/xrt_device.h>
#include <xrt/xrt_kernel.h>
#include <experimental/xrt_ip.h>
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>

#define DATA_SIZE 62500000
#define MAX_FILE_NUM 8

void wait_for_enter(const std::string &msg) {
  std::cout << msg << std::endl;
  std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
}

int main(int argc, char **argv) {
  if (argc != 5) {
    std::cout << "Usage: " << argv[0] << " <XCLBIN File> <local_IP> <serverPort> <data dir>" << std::endl;
    return EXIT_FAILURE;
  }

  std::string binaryFile = argv[1];

  // parse ip address
  uint32_t local_ip = 0;
  std::string ip_str = argv[2];
  std::string delim = ".";
  int ip[4];
  size_t pos = 0;
  std::string ip_token;
  int ip_idx = 0;
  while ((pos = ip_str.find(delim)) != std::string::npos) {
    ip_token = ip_str.substr(0, pos);
    ip[ip_idx] = stoi(ip_token);
    ip_str.erase(0, pos + delim.length());
    ip_idx++;
  }
  ip[ip_idx] = stoi(ip_str);
  local_ip = ip[3] | (ip[2] << 8) | (ip[1] << 16) | (ip[0] << 24);

  uint32_t board_number = 0;
  uint32_t server_port = stoi(std::string(argv[3]));

  // retrieve files
  std::string data_dir_path = argv[4];
  DIR* data_dir = opendir(data_dir_path.c_str());
  if (data_dir == nullptr) {
    printf("Error: directory %s not found\n", data_dir_path.c_str());
    return EXIT_FAILURE;
  }

  uint32_t file_num = 0;
  std::vector<std::string> file_name;
  dirent* ent;
  while ((ent = readdir(data_dir)) != nullptr) {
    if (ent->d_type == DT_REG) {
      std::string name(ent->d_name);
      if (name.size() <= 64) {
        file_name.push_back(name);
        file_num++;
      } else {
        printf("over 64 characters, skip %s\n", name.c_str());
      }
    }
  }
 
  if (file_num == 0) {
    printf("Error: file not found in directory %s\n", argv[4]);
    return EXIT_FAILURE;
  }

  auto device = xrt::device(0);
  std::cout << "device name: " << device.get_info<xrt::info::device::name>() << std::endl;
  std::cout << "device bdf: " << device.get_info<xrt::info::device::bdf>() << std::endl;
  auto xclbin_uuid = device.load_xclbin(binaryFile);

  printf("local_IP: %x, serverPort=%d\n", local_ip, server_port);

  auto network_krnl = xrt::kernel(device, xclbin_uuid, "network_krnl");

  // buffer allocate for network_krnl
  auto buf_size = sizeof(int) * DATA_SIZE;
  int* h_network_buf0;
  int* h_network_buf1; 
  posix_memalign((void**)&h_network_buf0, 4096, buf_size);
  posix_memalign((void**)&h_network_buf1, 4096, buf_size);
  memset(h_network_buf0, 0, buf_size);
  memset(h_network_buf1, 0, buf_size);
  auto network_buf0 = xrt::bo(device, h_network_buf0, buf_size, network_krnl.group_id(3));
  auto network_buf1 = xrt::bo(device, h_network_buf1, buf_size, network_krnl.group_id(4));
  network_buf0.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  network_buf1.sync(XCL_BO_SYNC_BO_TO_DEVICE);

  // set arg and run for network_krnl
  auto network_krnl_run = xrt::run(network_krnl);
  network_krnl_run.set_arg(0, local_ip);
  network_krnl_run.set_arg(1, board_number);
  network_krnl_run.set_arg(2, local_ip);
  network_krnl_run.set_arg(3, network_buf0);
  network_krnl_run.set_arg(4, network_buf1);
  network_krnl_run.start();
  network_krnl_run.wait();

  wait_for_enter("\nPress ENTER to continue after setting up ILA trigger...");

  auto http_server_krnl = xrt::ip(device, xclbin_uuid, "http_server_krnl");

  // load file list
  std::vector<uint64_t> file_size;
  std::vector<uint64_t> file_offset;

  uint64_t file_list_offset = 0;
  uint64_t file_offset_tmp = 0;
 
  uint8_t* h_file_list;
  posix_memalign((void**)&h_file_list, 4096, 128 * MAX_FILE_NUM);
  memset(h_file_list, 0, 128 * MAX_FILE_NUM);
  for (int i = 0; i < MAX_FILE_NUM; i++) {
    if (i >= (int)file_name.size()) {
      break;
    }
    std::string http_path = "/" + file_name[i];
    memcpy(&h_file_list[file_list_offset], http_path.c_str(), http_path.size());

    std::string file_path = data_dir_path + "/" + file_name[i];
    std::ifstream file(file_path, std::ifstream::ate | std::ifstream::binary);
    file_size.push_back(file.tellg());
    file_offset.push_back(file_offset_tmp);
    *(uint64_t*)&h_file_list[file_list_offset + 120] = file_size[i];
    *(uint64_t*)&h_file_list[file_list_offset + 112] = file_offset[i];
    file_list_offset += 128;
    file_offset_tmp = (file_offset_tmp + file_size[i] + 63) & ~63ULL;
  }

  for (uint32_t i = 0; i < file_num; i++) {
    printf("path=/%s size=%ld offset=%ld\n", file_name[i].c_str(), file_size[i], file_offset[i]);
  }

  // allocate file list buffer
  auto file_list = xrt::bo(device, h_file_list, 128 * MAX_FILE_NUM, 2);
  file_list.sync(XCL_BO_SYNC_BO_TO_DEVICE);

  uint64_t total_file_size = file_offset[file_num - 1] + file_size[file_num - 1];

  // allocate file data buffer
  uint8_t* h_file_data;
  posix_memalign((void**)&h_file_data, 4096, total_file_size);

  for (uint32_t i = 0; i < file_num; i++) {
    std::string file_path = data_dir_path + "/" + file_name[i];
    std::ifstream file(file_path, std::ios::in | std::ios::binary);
    file.read((char*)&h_file_data[file_offset[i]], file_size[i]);
  }

  auto file_data = xrt::bo(device, h_file_data, total_file_size, 2);
  file_data.sync(XCL_BO_SYNC_BO_TO_DEVICE);

  // set arg and run for http_server_krnl
  uint64_t file_list_addr = file_list.address();
  http_server_krnl.write_register(0x4, file_list_addr & 0xffffffff);
  http_server_krnl.write_register(0x8, file_list_addr >> 32);
  uint64_t file_data_addr = file_data.address();
  http_server_krnl.write_register(0xc, file_data_addr & 0xffffffff);
  http_server_krnl.write_register(0x10, file_data_addr >> 32);
  http_server_krnl.write_register(0x14, file_num);
  http_server_krnl.write_register(0x18, server_port);
  http_server_krnl.write_register(0x0, 1);  // start server

  return 0;
}
