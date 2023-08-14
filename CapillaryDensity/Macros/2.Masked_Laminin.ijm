#@String inputFolder

/////////////////////////////////////////////////////////////////////////////
//   Capillary Density Analysis
//   Copyright (C) 2023  Lenard M. Voortman and Tooba Abbassi-Daloii
//
//   This set of macros segments myofibers and capillaries and computes the capillary density.
//
//   Scripts:
//   step0_Convert_CZI_Merge_tiffs.bat:
//     > A simple batch script to convert multiple shading-corrected CZI files
//       into a single downsampled multichannel TIFF.
//   step1_Capillary_Density_Analysis_Pipeline.bat
//     > A simple batch script that runs all the necessary steps sequentially.
//
//   The steps are:
//   0.Convert_CZI_to_Tiff.ijm
//   1.Tiff_to_Mask.ijm
//   2.Masked_Laminin.ijm
//   3.Pixelclass_Laminin_Masked.ilp
//   4.Segment_Laminin.ijm
//
//   Note: The above steps were developed for myofiber typing analysis 
//   (https://github.com/tabbassidaloii/ImageProcessing/tree/main/MyofiberTyping/Macros) and 
//   are detailed in a STAR protocol: https://doi.org/10.1016/j.xpro.2023.102075
//
//   5.Eexport_Area.ijm
//   6.Export_Quant_CD31_CD105.ijm
//   
//      
//
//   Authors:   Lenard M. Voortman, Tooba Abbassi-Daloii
//   Version:   1.1 - Refactored for distribution
//   Version:   1.2 - Fixed bug when the number of sections > 9
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
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Close All");
maskExt = "_Mask.tif";
laminChannel = 4;
sigma = 4;
setBatchMode("hide");
run("Set Measurements...", "area mean centroid feret's median redirect=None decimal=3");
setOption("BlackBackground", true);
inputFolder = inputFolder + File.separator;

///////////////////////////////////////////////////////////////

list = getFileList(inputFolder);


for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	// Generic information
	
	currentFile=inputFolder+list[ik];

	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	filename = inputFolder+GlobalName + maskExt;
	outputfilename = inputFolder + GlobalName + "_Lamin_Masked.tif";

	filename_lamin = inputFolder + GlobalName + "_merged.tif";

	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);


	
	if(File.exists(outputfilename)){
		continue;
	}
	
	open(filename);
	NameMaskImage = getTitle();

	open(filename_lamin);
	rename("multichannel");
	run("Split Channels");
	selectWindow("C"+laminChannel+"-multichannel");
	NameImage = getTitle();

	selectWindow(NameMaskImage);
	run("Create Selection");
	run("Enlarge...", "enlarge=40 pixel");
	run("Create Mask");
	
	imageCalculator("Subtract create", "Mask",NameMaskImage);
	selectWindow("Result of Mask");
	run("Create Selection");
	
	selectWindow(NameImage);
	run("Restore Selection");

	medianValue = getValue("Median");
	run("Select None");
	
	selectWindow("Result of Mask");
	close();
	selectWindow("Mask");
	close();

	//print(medianValue);

	selectWindow(NameImage);
	run("32-bit");
	run("Subtract...", "value="+medianValue);
	
	selectWindow(NameMaskImage);
	run("Select None");
	
	run("Gaussian Blur...", "sigma="+sigma);
	imageCalculator("Multiply create 32-bit", NameMaskImage,NameImage);
	rename("lamin_masked");
	
	run("Divide...", "value=255.000");
	run("Add...", "value="+medianValue);
	setMinAndMax(0, 65536);
	run("16-bit");

	//save(outputfilename);
	run("Bio-Formats Exporter", "save=["+outputfilename+"] export compression=LZW");

	run("Close All");
}
print("Finished processing");

setBatchMode("show");

//eval("script", "System.exit(0);");
