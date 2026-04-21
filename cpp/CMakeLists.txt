cmake_minimum_required(VERSION 3.16)
project(misarblog-sdk VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(CURL REQUIRED)
find_package(nlohmann_json REQUIRED)

add_library(misarblog src/misarblog.cpp)
target_include_directories(misarblog PUBLIC include)
target_link_libraries(misarblog PRIVATE CURL::libcurl nlohmann_json::nlohmann_json)
