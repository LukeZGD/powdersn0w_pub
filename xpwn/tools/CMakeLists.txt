add_executable(asr_patcher asr_patcher.c)
target_link_libraries(asr_patcher xpwn)

add_executable(iboot_patcher iboot_patcher)
target_link_libraries(iboot_patcher xpwn)

add_executable(kernel_patcher kernel_patcher.c)
target_link_libraries(kernel_patcher xpwn)

