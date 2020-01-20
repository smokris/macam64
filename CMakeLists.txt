cmake_minimum_required(VERSION 3.16)
project(macam64 VERSION 0.1.0)

set(CMAKE_OSX_DEPLOYMENT_TARGET 10.10)

set(CMAKE_C_STANDARD 99)
string(JOIN " " CMAKE_C_FLAGS "${CMAKE_C_FLAGS}"
	-std=c99
	-march=x86-64
	-fvisibility-inlines-hidden
	-g
	-Wall
	-Wextra
	-Wimplicit-fallthrough
	-Wno-unused-parameter
	-Wno-c++11-extensions
	-Wno-sign-compare
	-Werror=implicit
)
set(CMAKE_C_FLAGS_RELEASE -Oz)
set(CMAKE_BUILD_TYPE Release)

add_library(macam64
	driver_core/MyCameraCentral.m
	driver_core/MyCameraDriver.m
	driver_core/MyCameraInfo.m
	driver_core/MyDummyCameraDriver.m

	cameras/CTDC1100Driver.m
	cameras/DivioDriver.m
	cameras/GenericDriver.m
	cameras/IBMcamDriver.m
	cameras/JL2005ADriver.m
	cameras/KworldTV300UDriver.m
	cameras/M560xDriver.m
	cameras/MyCPIACameraDriver.m
	cameras/MyKiaraFamilyDriver.m
	cameras/MyKiaraFlippedDriver.m
	cameras/MyOV511Driver.m
	cameras/MyPhilipsCameraDriver.m
	cameras/MyPixartDriver.m
	cameras/MyQCExpressADriver.m
	cameras/MyQCExpressBDriver.m
	cameras/MyQCOrbitDriver.m
	cameras/MyQCProBeigeDriver.m
	cameras/MyQCWebDriver.m
	cameras/MyQX3Driver.m
	cameras/MySE401Driver.m
	cameras/MySTV680Driver.m
	cameras/MySonix2028Driver.m
	cameras/MyTimonFamilyDriver.m
	cameras/OV534Driver.m
	cameras/PAC207Driver.m
	cameras/PAC7311Driver.m
	cameras/PixartDriver.m
	cameras/QCMessengerDriver.m
	cameras/QuickCamVCDriver.m
	cameras/R5U870Driver.m
	cameras/SQ905.m
	cameras/SQ905C.m
	cameras/UVCDriver.m
	cameras/WinbondDriver.m
	cameras/pwc_files/pwc-dec23.c
	cameras/pwc_files/pwc-kiara.c
	cameras/pwc_files/pwc-misc.c
	cameras/pwc_files/pwc-timon.c
	cameras/pwc_files/pwc-uncompress.c

	# Build errors
	# cameras/CX11646Driver.m
	# cameras/ET61xx51Driver.m
	# cameras/MR97311Driver.m
	# cameras/SPCA500Driver.m
	# cameras/SPCA501ADriver.m
	# cameras/SPCA504Driver.m
	# cameras/SPCA505Driver.m
	# cameras/SPCA506Driver.m
	# cameras/SPCA508Driver.m
	# cameras/SPCA525Driver.m
	# cameras/SPCA533Driver.m
	# cameras/SPCA536Driver.m
	# cameras/SPCA551Driver.m
	# cameras/SPCA561ADriver.m
	# cameras/SPCA5XX.m
	# cameras/SPCA5XXDriver.m
	# cameras/SPCA5xxExampleDriver.m
	# cameras/SonixDriver.m
	# cameras/TV8532Driver.m
	# cameras/VC032xDriver.m
	# cameras/ZC030xDriver.m
	# cameras/ZR36430Driver.m

	# QuickTime
	# cameras/MyIntelPCCameraPro.m
	# cameras/MySPCA500Driver.m
	# cameras/MySPCA504Driver.m
	# cameras/MyVicamDriver.m
	# cameras/OV519Driver.m
	# cameras/PicoDriver.m
	# cameras/SQ930C.m
	# cameras/TP68xxDriver.m

	utilities/MiniGraphicsTools.c
	utilities/MiscTools.c
	utilities/Resolvers.c
	utilities/yuv2rgb.c
)
target_compile_definitions(macam64
	PRIVATE
		VERBOSE
		# REALLY_VERBOSE
		# LOG_MEM_CALLS
		# LOG_USB_CALLS
)
target_include_directories(macam64
	PRIVATE
		app_specific
		cameras
		cameras/stv600_sensors
		driver_core
		sensors
		utilities
)
