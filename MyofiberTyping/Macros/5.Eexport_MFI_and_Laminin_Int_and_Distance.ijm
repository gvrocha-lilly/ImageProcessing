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

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

roiManager("reset");
maskExt = "_Lamin_Segmentation.tif";
run("Close All");
run("Options...", "iterations=1 count=1 black do=Nothing");

setBatchMode("hide");

///////////////////////////////////////////////////////////////

list = getFileList(inputFolder);
for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

ROIDir=inputFolder+"ROI\\";
CheckDir=inputFolder+"check\\";
if(File.exists(CheckDir) < 1){
	File.makeDirectory(CheckDir);
}



/////////////////////////////
r_min = 143;
r_max = 1000;
g_min = 632;
g_max = 6436;
b_min = 582;
b_max = 8697;

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	currentFile=inputFolder+list[ik];

	GlobalName = File.getNameWithoutExtension(currentFile);
	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	
	filename      = inputFolder + GlobalName + "_merged.tif";
	filename_prob = inputFolder + GlobalName + "_Lamin_Masked_Probabilities.tif";
	filename_seg  = inputFolder + GlobalName + "_Lamin_Segmentation.tif";
	filename_mask = inputFolder + GlobalName + "_Mask.tif";

	filename_export1 = CheckDir + GlobalName + "_check1.jpg";
	filename_export2 = CheckDir + GlobalName + "_check2.jpg";
	filename_export3 = CheckDir + GlobalName + "_check3.jpg";

	filename_ROI = ROIDir + GlobalName + "_ROI.zip";
	filename_MFI = ROIDir + GlobalName + "_MFI.txt";

	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);

	open(filename_mask);
	NameMaskImage = getTitle();

	selectWindow(NameMaskImage);
	run("Create Selection");
	roiManager("Add");
	
	open(filename);
	rename("multichannel");
	setSlice(1);
	run("Blue");
	setMinAndMax(b_min, b_max);
	setSlice(2);
	run("Red");
	setMinAndMax(r_min, r_max);
	setSlice(3);
	run("Green");
	setMinAndMax(g_min, g_max);
	setSlice(4);
	roiManager("Select", 0);
	run("Enhance Contrast", "saturated=7.5");

	open(filename_prob);
	rename('ch5');
	NameCh5Image = getTitle();
	run("16-bit");
	selectWindow(NameCh5Image);
	setMinAndMax(0, 255);

	open(filename_seg);
	NameSegmentationImage = getTitle();

	selectWindow("multichannel");
	run("Split Channels");
	run("Merge Channels...", "c1=C1-multichannel c2=C2-multichannel c3=C3-multichannel c4=C4-multichannel c5=ch5 create");
	Stack.setActiveChannels("11110");
	getPixelSize(unit, pixelWidth, pixelHeight);
	rename(GlobalName);
	
	NameLamininImage = GlobalName;
	
	//////////////////////

	roiManager("reset");
	roiManager("open", filename_ROI);
	run("Set Measurements...", "area mean standard modal min shape median display redirect=None decimal=3");
	run("Clear Results");

	roiManager("multi-measure measure_all");

	///////////// Boundary measurement
	setBatchMode("hide");
	
	nchannels = 5;
	nROIs = roiManager("count");
	for (m = 0; m < nROIs; m++) {
		roiManager("Select", m);
		run("Enlarge...", "enlarge=3 pixel");
		roiManager("Add");
		
		roiManager("Select", newArray(m,nROIs)); // nROIs is the latest addition (original range 0 to nROIS-1)
		
		roiManager("XOR");
		roiManager("Add");

		for (n = 0; n < nchannels; n++){
			setSlice(n+1);
			
			mean = getValue("Mean");
			std = getValue("StdDev");
						
			setResult("Mean_boundary",n*nROIs + m,mean);
			setResult("StdDev_boundary",n*nROIs + m,std);
		}
		
		roiManager("Select",newArray(nROIs,nROIs+1));
		roiManager("Delete");
	}
	updateResults();

	///////////// Distance measurement
	selectWindow(NameMaskImage);
	run("Select None");
	run("Remove Overlay");
	run("Distance Map");
	for (m = 0; m < nROIs; m++) {
		roiManager("Select", m);
		mean = getValue("Mean");
		
		for (n = 0; n < 5; n++){
			setResult("Mean_distance",n*nROIs + m,mean);
		}
	}
	updateResults();

	/////////////
	
	saveAs("Results", filename_MFI);

	////////////
	
	selectWindow(NameSegmentationImage);
	run("RGB Color");
	roiManager("Show None");
	run("Invert");

	nROIs = roiManager("count");
	for (n = 0; n < nROIs; n++) {
		r = getResult("Mean", n + nROIs*1);
		g = getResult("Mean", n + nROIs*2);
		b = getResult("Mean", n + nROIs*0);
		
		r = (r - r_min)/(r_max - r_min)*255;
		g = (g - g_min)/(g_max - g_min)*255;
		b = (b - b_min)/(b_max - b_min)*255;
		
		roiManager("select", n);
		
		setForegroundColor(r, g, b);
		run("Fill", "slice");
	}
	//setBatchMode("exit and display");

	
	selectWindow(NameSegmentationImage);
	run("Properties...", "unit="+unit+" pixel_width="+pixelWidth+" pixel_height="+pixelHeight+" voxel_depth=1");
	roiManager("Show None");
	run("Hide Overlay");
	run("Scale Bar...", "width=1000 height=8 font=28 color=White background=None location=[Lower Right] bold overlay");
	saveAs("Jpeg", filename_export2);
	close();
	
	////////////
	
	selectWindow(NameLamininImage);
	roiManager("Show None");
	run("Hide Overlay");
	run("Remove Overlay");
	run("RGB Color");
	run("Scale Bar...", "width=1000 height=8 font=28 color=White background=None location=[Lower Right] bold overlay");
	run("Flatten");
	saveAs("Jpeg", filename_export1);
	
	roiManager("Show All with labels");
	run("Flatten");
	saveAs("Jpeg", filename_export3);
	
	//////////////////////////////////////
	
	roiManager("reset");
	run("Close All");
}

eval("script", "System.exit(0);");