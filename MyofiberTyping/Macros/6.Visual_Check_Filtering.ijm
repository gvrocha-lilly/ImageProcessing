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

function Import_Results_Table(filename) {
     requires("1.35r");
     lineseparator = "\n";
     cellseparator = ",\t";

     // copies the whole RT to an array of lines
     lines=split(File.openAsString(filename), lineseparator);

     // recreates the columns headers
     labels=split(lines[0], cellseparator);
     if (labels[0]==" ")
        k=1; // it is an ImageJ Results table, skip first column
     else
        k=0; // it is not a Results table, load all columns
     for (j=k; j<labels.length; j++)
        setResult(labels[j],0,0);

     // dispatches the data into the new RT
     run("Clear Results");
     for (i=1; i<lines.length; i++) {
        items=split(lines[i], cellseparator);
        for (j=k; j<items.length; j++)
           setResult(labels[j],i-1,items[j]);
     }
     updateResults();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

maskExt = "_Filt.txt";              // filename to search for modified results table (in ROI dir)
exportN = 4;                       // index of the filename, e.g. "_check5.jpg"
exportColumn = "Included_SeqQAreaCirc";    // Column to export from the modified results table
exportMin = 0;                     // min value to be displayed as black (0,0,0)
exportMax = 1;                   // max value to be displayed as white (255,255,255)
exportBG = 128;                    // value to use for the background, e.g. 128 = mid gray

roiManager("reset");
run("Close All");
run("Options...", "iterations=1 count=1 black do=Nothing");

setBatchMode("hide");

///////////////////////////////////////////////////////////////
ROIDir=inputFolder+"ROI\\";
CheckDir=inputFolder+"check\\";

list = getFileList(ROIDir);
for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], maskExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 

	currentFile=inputFolder+list[ik];
	
	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(maskExt));
	
	filename_mask = inputFolder + GlobalName + "_Mask.tif";

	filename_ROI = ROIDir + GlobalName + "_ROI.zip";
	filename_MFI = ROIDir + GlobalName + maskExt;
	
	filename_export = CheckDir + GlobalName + "_check"+exportN+".jpg";
	
	if(!File.exists(filename_ROI)){
		continue;
	}
	if(File.exists(filename_export)){
		continue;
	}

	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);
	
	open(filename_mask);
	NameMaskImage = getTitle();

	open(filename_ROI);
	

	selectWindow(NameMaskImage);

	Import_Results_Table(filename_MFI);

	setForegroundColor(exportBG, exportBG, exportBG);
	run("Select All");
	run("Clear", "slice");
	run("Select All");
	run("Fill", "slice");
		
	nROIs = roiManager("count");
	for (n = 0; n < nROIs; n++) {
		r = getResult(exportColumn, n);
		
		r = (r - exportMin)/(exportMax - exportMin)*255;
		
		roiManager("select", n);
		
		setForegroundColor(r, r, r);
		run("Fill", "slice");
	}
	
	roiManager("Show None");
	run("Hide Overlay");
	saveAs("Jpeg", filename_export);
	
	roiManager("reset");
	run("Clear Results");
	run("Close All");
}

//eval("script", "System.exit(0);");