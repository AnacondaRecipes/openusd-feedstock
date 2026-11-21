cmake_minimum_required(VERSION 3.26)
project(pxr_consumer LANGUAGES CXX)

find_package(pxr REQUIRED)

add_executable(pxr_consumer main.cpp)
target_link_libraries(pxr_consumer PRIVATE usd usdGeom)
