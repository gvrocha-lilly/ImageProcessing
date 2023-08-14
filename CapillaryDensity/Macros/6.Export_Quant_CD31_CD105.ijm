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


/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Close All");
run("Clear Results");
roiManager("reset");
maskExt = "_Mask.tif";
CD31Channel = 2;
CD105Channel = 3;
setBatchMode("hide");
inputFolder = inputFolder + File.separator;

roiManager("reset");

///////////////////////////////////////////////////////////////

list = getFileList(inputFolder);


for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

quantification_folder = inputFolder + "Quantification/";
File.makeDirectory(quantification_folder);

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	// Generic information
	
	currentFile=inputFolder+list[ik];

	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	filename = inputFolder + GlobalName + maskExt;
	filename_input = inputFolder + GlobalName + "_merged.tif";
	filename_lamin = inputFolder + GlobalName + "_Lamin_Segmentation.tif";
	outputCD31segfilename = quantification_folder + GlobalName + "_CD31_AnalyzeParticles.txt";

	outputCD31_mask = inputFolder + GlobalName + "_CD31mask.tif";
	outputCD105_mask = inputFolder + GlobalName + "_CD105mask.tif";
	outputCapillary_mask = inputFolder + GlobalName + "_CapillaryMask.tif";
	
	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);


	// Make tissue mask based on mask image
	open(filename);
	setThreshold(128, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Create Selection");
	roiManager("add");
	close();

	// ONLY IMPORT CD31 CHANNEL
	run("Bio-Formats Importer", "open=["+filename_input+"] specify_range view=Hyperstack stack_order=XYCZT c_begin=" + CD31Channel + " c_end=" + CD31Channel + " c_step=1");
	rename("C" + CD31Channel + "-multichannel");
	NameImageCD31 = getTitle();
	
	// create CD31 mask
	run("Duplicate...", "title=maskCD31");
	run("Gaussian Blur...", "sigma=1");
	roiManager("Select", 0);
	setAutoThreshold("Li dark");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Fill Holes");
	run("Watershed");
	roiManager("Select", 0);
	run("Clear Outside");
	run("Select None");

	// export CD31 mask
	run("Bio-Formats Exporter", "save=["+outputCD31_mask+"] export compression=LZW");

	// open lamin segmentation (mask)
	open(filename_lamin);
	NameImageLaminSeg = getTitle();
	run("Invert");
	
	// calculate intersection of lamin mask and CD31 mask
	imageCalculator("AND create", "maskCD31", NameImageLaminSeg);
	rename("capillary_mask");
	
	// export Capillary mask
	run("Bio-Formats Exporter", "save=["+outputCapillary_mask+"] export compression=LZW");

	// measure CD31 intensity
	selectImage("capillary_mask");
	run("Set Measurements...", "area mean standard modal min center shape median display redirect=["+NameImageCD31+"] decimal=3");
	run("Analyze Particles...", "display clear");
	saveAs("Results", outputCD31segfilename);
	run("Clear Results");

	// ONLY IMPORT CD105 CHANNEL
	run("Bio-Formats Importer", "open=["+filename_input+"] specify_range view=Hyperstack stack_order=XYCZT c_begin=" + CD105Channel + " c_end=" + CD105Channel + " c_step=1");
	rename("C" + CD105Channel + "-multichannel");
	NameImageCD105 = getTitle();
		
	// measure CD105 intensity
	selectImage("capillary_mask");
	run("Set Measurements...", "area mean standard modal min center shape median display redirect=["+NameImageCD105+"] decimal=3");
	run("Analyze Particles...", "display clear");
	saveAs("Results", outputCD105segfilename);
	run("Clear Results");
	
	// clean up for next iterationi
	roiManager("reset");
	run("Close All");
}
print("Finished processing");

setBatchMode("show");

//eval("script", "System.exit(0);");