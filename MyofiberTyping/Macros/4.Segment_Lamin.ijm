#@String inputFolder

/////////////////////////////////////////////////////////////////////////////
//   Myofiber Segmentation and Analysis
//   Copyright (C) 2021  Lenard M. Voortman
//
//   This set of macros segments and analyses myofiber images
//
//   step0_Convert_CZI_Merge_tiffs.bat
//     > simple batch script to convert multiple shading corrected CZI files
//       into single downsampled multichannel tiff
//   step1_Myofiber_Analysis_Pipeline.bat
//     > simple batch script that runs all the necessary steps sequentially
//   
//   0.Convert_CZI_to_Tiff.ijm
//   1.Tiff_to_Mask.ijm
//   2.Masked_Lamin.ijm
//   3.Pixelclass_Lamin_Masked.ijm
//   4.Segment_Lamin.ilp
//   5.Eexport_MFI_and_Laminin_Int_and_Distance.ijm
//   6.Visual_Check_Filtering.ijm
//
//   Authors:   Lenard M. Voortman
//   Version:   1.1 - refactored for distribution
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License.
// 
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
// 
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function FiberShapeDetectionOnLaminin(NameLamininImage,filename_seg) {
	
	// Segmentation of Fibers
	selectWindow(NameLamininImage);
	run("Duplicate...", "title=[Fiber Temp]");
	selectWindow("Fiber Temp");
	
	run("Gaussian Blur...", "sigma=2");

	roiManager("Select", 0);

	ThresholdF = 32;
	
	run("Find Maxima...", "noise="+ThresholdF+" output=[Segmented Particles] light");
	
	selectWindow("Fiber Temp Segmented");
	run("Invert");
	run("Options...", "iterations=1 count=1 black do=Dilate");
	run("Options...", "iterations=2 count=1 black do=Close");
	run("Invert");

	//save(filename_seg);
	run("Bio-Formats Exporter", "save=["+filename_seg+"] export compression=LZW");
	//close();
	
	selectWindow("Fiber Temp");
	run("Close");
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Set Measurements...", "area mean centroid feret's redirect=None decimal=3");
roiManager("reset");
maskExt = "_Lamin_Masked_Probabilities.tif";
run("Close All");
setOption("BlackBackground", true);
run("Options...", "iterations=1 count=1 black do=Nothing");
inputFolder = inputFolder + File.separator;

setBatchMode("hide");

///////////////////////////////////////////////////////////////

list = getFileList(inputFolder);
for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

ROIDir=inputFolder+"ROI\\";
if(File.exists(ROIDir) < 1){
	File.makeDirectory(ROIDir);
}

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	// Generic information
	currentFile=inputFolder+list[ik];

	GlobalName = File.getNameWithoutExtension(currentFile);
	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	
	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);
	
	filename = inputFolder + GlobalName + "_Lamin_Masked_Probabilities.tif";
	filename_seg = inputFolder + GlobalName + "_Lamin_Segmentation.tif";
	filename_mask = inputFolder + GlobalName + "_Mask.tif";
	
	filename_ROI = ROIDir + GlobalName + "_ROI.zip";
	filename_MFI = ROIDir + GlobalName + "_MFI.txt";
	
	print("Open File: "+filename);
	open(filename);
	NameLamininImage = getTitle();

	print("Open File: "+filename_mask);
	open(filename_mask);
	NameMaskImage = getTitle();
	//selectWindow(NameMaskImage);
	run("Create Selection");
	roiManager("Add");
	
	// Fiber shape detection on Laminin
	FiberShapeDetectionOnLaminin(NameLamininImage,filename_seg);

	selectWindow("Fiber Temp Segmented");
	roiManager("Select", 0); // ROI selected as max area

	MinArea=100;
	MaxArea = 10000000; //LMV
	run("Analyze Particles...", "size=MinArea-MaxArea circularity=0.1-1.00 add");
	
	roiManager("Select", 0); // ROI selected as max area
	roiManager("Delete");

	roiManager("Save", filename_ROI);
	

	roiManager("reset");
	run("Close All");
}

eval("script", "System.exit(0);");
