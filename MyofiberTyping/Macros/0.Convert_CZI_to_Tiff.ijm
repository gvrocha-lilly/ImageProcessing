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
//   Version:   1.2 - fixed bug when number of sections > 9
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


scalef = 0.25;

/////////////////////////////////////////////////////////////////////////////
function getCZIPyramidSeriesIDs(){
	// create an empty array
	ids = newArray(1000);
	
	// seriescount is the total of image distributed over different pyramids plus label image and preview
	Ext.getSeriesCount(seriesCount);

	// substract 2 for label and template image;
	seriesCount = seriesCount - 2; 
	//print("seriesCount "+seriesCount);
	
	metadatakey = "Information|Image|SizeS";
	Ext.getMetadataValue(metadatakey, SizeS);
	SizeS = parseInt(SizeS);
	//print("SizeS: "+SizeS);
	
	layers = newArray(SizeS);
	//print("layers size"+lengthOf(layers));
	for(i = 0; i < SizeS; i++) {
		pyramidStringID = "" + i+1;
		
		nr0s = lengthOf("" + SizeS) - lengthOf("" + i + 1);
		for (k = 0; k < nr0s; k++) {
			pyramidStringID = "0" + pyramidStringID;
		}
		//print(pyramidStringID);
		
		metadatakey = "Information|Image|S|Scene|PyramidInfo|PyramidLayersCount #" + pyramidStringID;
		Ext.getMetadataValue(metadatakey, value);
		value = parseInt(value);

		layers[i] = value+1;
	}
	check = 0;
	for(i = 0; i < SizeS; i++) {
		check = check + layers[i];
	}
	
	//print("check: "+check);
	if(check != seriesCount){
		approximation = round(seriesCount / SizeS);
		if(approximation * SizeS == seriesCount){
			for(i = 0; i < SizeS; i++) {
				layers[i] = approximation;
			}
		}else{
			exit("unresolvable Layer info");
		}
	}
	
	i = 0;
	for(seriesN = 0; seriesN < SizeS; seriesN++){
		ids[seriesN] = i;
		
		value = layers[seriesN];
		
		i = i+value;
	}
	ids = Array.trim(ids, SizeS);

	return ids;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Bio-Formats Macro Extensions");
run("Close All");
setBatchMode("hide");
inputFolder = inputFolder + File.separator;

///////////////////////////////////////////////////////////////
list = getFileList(inputFolder);
for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], ".czi")){   // if the filename does not end with .czi, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){
	currentFile=inputFolder+list[ik];

	GlobalName = File.getNameWithoutExtension(currentFile);

	// Check whether this is a 'Shading Correction' single channel .czi file
	isSingleChannel = 0;
	ShadingCorrIdx = indexOf(GlobalName, "-Shading Correction-");
	if(ShadingCorrIdx > 0){
		print("This is a single channel file");
		isSingleChannel = 1;
		GlobalName = substring(GlobalName, 0, ShadingCorrIdx);
	}

	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);

	// initialize BioFormats to the right file
	Ext.setId(currentFile);
	seriesIDs = getCZIPyramidSeriesIDs();

	print("This file contains " + seriesIDs.length + " ScanRegions");

	for (im=0; im<seriesIDs.length; im++){
		print("Now processing scanArea: "+(im+1)+", seriesID: " + seriesIDs[im]);
		NameLamininImage = GlobalName + "_s" + im;
		
		// point BioFormats to the correct series
		Ext.setSeries(seriesIDs[im]);
		Ext.getImageCount(imageCount);
		
		if (isSingleChannel){
			print("Image is a single channel image");
			
			outputfilename = inputFolder + NameLamininImage + ".tif";
			
			if(File.exists(outputfilename)){
				continue;
			}
			
			// open single channel
			Ext.openImage("", 0);
			rename("c0");

			// scale 1 levels down
			selectWindow("c0");
			run("Scale...", "x="+scalef+" y="+scalef+" interpolation=Bilinear average create");
			selectWindow("c0");
			close();

			selectWindow("c0-1");
			save(outputfilename);
		}else{
			Ext.getSizeC(sizeC)
			print("Image is a "+sizeC+" channel image");
			
			outputfilename = inputFolder + NameLamininImage + "_merged.tif";
			
			if(File.exists(outputfilename)){
				continue;
			}

			
			merge_cmd = "";
			for (c = 0; c < sizeC; c++) {
				// open the n channels
				Ext.openImage("", c);
				rename("c"+c);

				// scale 1 levels down
				selectWindow("c"+c);
				run("Scale...", "x="+scalef+" y="+scalef+" interpolation=Bilinear average create");

				selectWindow("c"+c);
				close();

				merge_cmd = merge_cmd + "c"+(c+1)+"=c"+c+"-1 ";
			}
			merge_cmd = merge_cmd + "create";
			//print(merge_cmd);
			run("Merge Channels...", merge_cmd);
			
			rename(NameLamininImage);

			save(outputfilename);
		}
		run("Close All");
	}
}
print("Finished processing");

setBatchMode("show");

eval("script", "System.exit(0);");
