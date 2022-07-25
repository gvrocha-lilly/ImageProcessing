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


/////////////////////////////////////////////////////////////////////////////
function getCZIPyramidSeriesIDs(){
	// create an empty array
	ids = newArray(1000);
	
	// seriescount is the total of image distributed over different pyramids plus label image and preview
	Ext.getSeriesCount(seriesCount);

	// substract 2 for label and template image;
	seriesCount = seriesCount - 2; 
	//print("seriesCount "+seriesCount);
	
	metadatakey = "Information|Image|SizeS #1";
	Ext.getMetadataValue(metadatakey, SizeS);
	SizeS = parseInt(SizeS);
	//print("SizeS: "+SizeS);
	
	layers = newArray(SizeS);
	//print("layers size"+lengthOf(layers));
	for(i = 0; i < SizeS; i++) {
		metadatakey = "Information|Image|S|Scene|PyramidInfo|PyramidLayersCount #" + i+1;
		Ext.getMetadataValue(metadatakey, value);
		value = parseInt(value);
		//print(i);
		//print(lengthOf(layers));
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
			outputfilename = inputFolder + NameLamininImage + ".tif";
			
			if(File.exists(outputfilename)){
				continue;
			}
			
			// open single channel
			Ext.openImage("", 0);
			rename("c0");

			// scale 1 levels down
			selectWindow("c0");
			run("Scale...", "x=0.25 y=0.25 interpolation=Bilinear average create");
			selectWindow("c0");
			close();

			selectWindow("c0-1");
			save(outputfilename);
		}else{
			outputfilename = inputFolder + NameLamininImage + "_merged.tif";
			
			if(File.exists(outputfilename)){
				continue;
			}
			
			// open the 4 channels
			Ext.openImage("", 0);
			rename("c0");
			Ext.openImage("", 1);
			rename("c1");
			Ext.openImage("", 2);
			rename("c2");
			Ext.openImage("", 3);
			rename("c3");

			// scale 1 levels down
			selectWindow("c0");
			run("Scale...", "x=0.25 y=0.25 interpolation=Bilinear average create");
			selectWindow("c1");
			run("Scale...", "x=0.25 y=0.25 interpolation=Bilinear average create");
			selectWindow("c2");
			run("Scale...", "x=0.25 y=0.25 interpolation=Bilinear average create");
			selectWindow("c3");
			run("Scale...", "x=0.25 y=0.25 interpolation=Bilinear average create");
			selectWindow("c3");
			close();
			selectWindow("c2");
			close();
			selectWindow("c1");
			close();
			selectWindow("c0");
			close();

			//selectWindow("c3-1");
			//save(inputFolder + NameLamininImage + "_Lamin.tif");
			//rename("c3-1");
			
			run("Merge Channels...", "c1=c0-1 c2=c1-1 c3=c2-1 c4=c3-1 create");
			
			rename(NameLamininImage);

			save(outputfilename);
		}
		run("Close All");
	}
}
print("Finished processing");

setBatchMode("show");

eval("script", "System.exit(0);");