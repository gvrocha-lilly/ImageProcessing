@echo off
setlocal EnableDelayedExpansion

:: Note: replace the path below with complete path to CZI datasets
SET datapath=I:\tabbassidaloii\ImageProcessing\MyofiberTyping\Samples\ 

:: Note: replace the path below with complete path to macro files
SET macropath=I:\\tabbassidaloii\ImageProcessing\MyofiberTyping\Macros\ 

:: Note: replace the path below with complete path to Fiji app
SET imagejPath=C:\Fiji.app\ImageJ-win64.exe

%imagejPath% --ij2 --headless --console --run "%macropath%0.Convert_CZI_to_Tiff.ijm" "inputFolder='%datapath%'"

