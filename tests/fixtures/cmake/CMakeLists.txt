cmake_minimum_required(VERSION 3.16)
project(plain_cmake LANGUAGES C CXX)
add_executable(example src/main.c)
target_include_directories(example PRIVATE include)
