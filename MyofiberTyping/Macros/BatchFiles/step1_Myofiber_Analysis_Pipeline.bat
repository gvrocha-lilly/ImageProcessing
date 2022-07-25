@echo off
setlocal EnableDelayedExpansion

:: Note: replace the path below with complete path to CZI datasets
SET datapath=I:\tabbassidaloii\ImageProcessing\MyofiberTyping\Samples\ 

:: Note: replace the path below with complete path to macro files
SET macropath=I:\\tabbassidaloii\ImageProcessing\MyofiberTyping\Macros\ 

:: Note: replace the path below with complete path to Fiji app
SET imagejPath=C:\Fiji.app\ImageJ-win64.exe

:: Note: replace the path below with complete path to Ilastik app
SET ilastikpath=C:\Program Files\ilastik-1.3.3post3\ilastik.exe



%imagejPath% --ij2 --console --run "%macropath%1.Tiff_to_Mask.ijm" "inputFolder='%datapath%'"
%imagejPath% --ij2 --console --run "%macropath%2.Masked_Lamin.ijm" "inputFolder='%datapath%'"

set filelist=
FOR /F "delims=" %%G in ('dir /b "%datapath%*_Lamin_Masked.tif"') do set filelist=!filelist! "%datapath%%%G"
"%ilastikpath%" --headless --project="%macropath%3.Pixelclass_Lamin_Masked.ilp" %filelist%

%imagejPath% --ij2 --console --run "%macropath%4.Segment_Lamin.ijm" "inputFolder='%datapath%'"
%imagejPath% --ij2 --console --run "%macropath%5.Eexport_MFI_and_Laminin_Int_and_Distance.ijm" "inputFolder='%datapath%'"
