INCLUDE(FindOpenSSL)
INCLUDE(FindZLIB)

FIND_LIBRARY(CRYPTO_LIBRARIES crypto
      PATHS
      /usr/lib
      /usr/local/lib
   )

find_package(Threads REQUIRED)

IF(NOT ZLIB_FOUND)
	message(FATAL_ERROR "zlib is required for dmg!")
ENDIF(NOT ZLIB_FOUND)

include_directories(${ZLIB_INCLUDE_DIR})
link_directories(${ZLIB_LIBRARIES})

link_directories(${PROJECT_BINARY_DIR}/common ${PROJECT_BINARY_DIR}/hfs)

add_library(dmg checksum.c dmgfile.c dmglib.c filevault.c io.c partition.c resources.c udif.c)

IF(OPENSSL_FOUND)
	add_definitions(-DHAVE_CRYPT)
	include_directories(${OPENSSL_INCLUDE_DIR})
	target_link_libraries(dmg ${CRYPTO_LIBRARIES})
	IF(WIN32)
		TARGET_LINK_LIBRARIES(dmg gdi32)
	ENDIF(WIN32)
ENDIF(OPENSSL_FOUND)

target_link_libraries(dmg common hfs z ${CMAKE_DL_LIBS} ${CMAKE_THREAD_LIBS_INIT})
