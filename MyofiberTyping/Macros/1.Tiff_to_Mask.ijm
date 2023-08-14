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
/////////////////////////////////////////////////////////////////////////////
function ArtefactDetectionOnLaminin(imgWindowTitle) {

	selectWindow(imgWindowTitle);
	run("Duplicate...", "title=[Fiber Temp]");
	getStatistics(area, mean, min, max, std, histogram);
	getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);

	// restrict to area that is not clipped to 0 (outside scan area)
	setThreshold(1, 65535, "raw");
	run("Create Selection");
	
	//MinArea=1000;
	MinArea=0.01*area;
	rejectBoundary = 0.2;

	// Segmentation of entire section
	run("Enhance Contrast", "saturated=0.60 normalize equalize");
	run("Subtract Background...", "rolling=20");
	run("Gaussian Blur...", "sigma=5");
	run("Enhance Contrast...", "saturated=1 normalize");
	
	setAutoThreshold("Li dark");
	
	run("Convert to Mask");
	run("Fill Holes");
	//run("Analyze Particles...", "size="+MinArea+"-Infinity add display clear");
	run("Analyze Particles...", "size="+MinArea+"-Infinity add");

	// Max Area has been kept
	MaxSurf = 0;
	KeepIndex = 0;
	for (i=0; i<roiManager("count"); i++) {
		roiManager("Select", i);
		Roi.getContainedPoints(xpoints, ypoints);

		m = xpoints.length;
		r2_rel = m/PI;
		inertia_ref = 1/2*m*r2_rel;
		
		inertia = 0;
		for(n=0;n<xpoints.length;n++){
			xrel = (xpoints[n] - width/2);
			yrel = (ypoints[n] - height/2);
			r2 = xrel*xrel + yrel*yrel;
			inertia = inertia + r2;
		}
		
		inertia_rel = inertia/inertia_ref;
		//print("inertia:"+inertia+" ,ref: "+ inertia_ref +", relative: "+inertia_rel);
		
		Array.getStatistics(xpoints, xmin, xmax, xmean, xstdDev);
		Array.getStatistics(ypoints, ymin, ymax, ymean, ystdDev);
		//Array.getStatistics(rpoints, rmin, rmax, rmean, rstdDev);
		
		CurrentArea=xpoints.length*pixelWidth*pixelHeight;
		CurrentXp=xmean/width;
		CurrentYp=ymean/width;
		
		//print("CurrentArea:"+String.format("%08.0f", CurrentArea)+",I:"+String.format("%4.2f", inertia_rel)+",Xp:"+String.format("%4.2f", CurrentXp)+",Yp:"+String.format("%4.2f", CurrentYp));

		if ( inertia_rel > 5) {
			//print("skipping due to Inertia");
			continue;
		}

		if ( CurrentXp < rejectBoundary || 
		     CurrentXp > 1-rejectBoundary || 
		     CurrentYp < rejectBoundary || 
		     CurrentYp > 1-rejectBoundary) {
			//print("skipping");
			continue;
		}
		
		if (MaxSurf < CurrentArea) {
			KeepIndex=i;
			MaxSurf=CurrentArea;
			//print("new max");
		}
	}
	//run("Close");
	
	if (roiManager("count") > 1) {
		// Use reverse sort to maintain indexing
		for (i=roiManager("count")-1; i >= 0; i--) {
			if (i != KeepIndex) {
				roiManager("Select", i);
				roiManager("Delete");
			}
		}
	}
	
	selectWindow("Fiber Temp");
	close();

	return;
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////        					MAIN PROGRAM            				////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////

run("Close All");
laminExt = "_merged.tif";
laminChannel = 4;
setBatchMode("hide");
run("Set Measurements...", "area mean centroid feret's redirect=None decimal=3");
setOption("BlackBackground", true);
inputFolder = inputFolder + File.separator;

///////////////////////////////////////////////////////////////
list = getFileList(inputFolder);
for (ik=list.length-1; ik>=0; ik--){ // for loop to parse through files in main folder 
	if(!endsWith(list[ik], laminExt)){   // if the filename does not end with correct part, pop it from the list
		list = Array.deleteIndex(list, ik);
	}
}

/////////////////////////////////////////////////////////////////////
print(inputFolder+"==> "+list.length+" set of images to treat");

for (ik=0; ik<list.length; ik++){ // for loop to parse through names in main folder 
	currentFile=inputFolder+list[ik];

	GlobalName = substring(list[ik],0,lengthOf(list[ik]) - lengthOf(laminExt));
	outputfilename = inputFolder + GlobalName + "_Mask.tif";
	
	print("File "+(ik+1)+" of " + list.length + " in process: "+GlobalName);
	
	if(File.exists(outputfilename)){
		continue;
	}
	
	open(inputFolder + GlobalName + laminExt);
	rename("multichannel");
	
	imgWindowTitle = "Fiber";
	run("Duplicate...", "title="+imgWindowTitle+" duplicate channels="+laminChannel);
	
	ArtefactDetectionOnLaminin(imgWindowTitle);
	selectWindow(imgWindowTitle);
	close();
	
	selectWindow("multichannel");

	if (roiManager("count") == 1){
		roiManager("Select", 0);
	}
	
	setSlice(1);
	run("Blue");
	run("Enhance Contrast", "saturated=0.35");
	setSlice(2);
	run("Red");
	run("Enhance Contrast", "saturated=0.35");
	setSlice(3);
	run("Green");
	run("Enhance Contrast", "saturated=0.35");
	setSlice(4);
	run("Grays");
	run("Enhance Contrast", "saturated=0.35");
	
	setBatchMode("show");
	waitForUser("Is the mask OK?", "Please modify selection when necessary.");
	setBatchMode("hide");
	
	run("Create Mask");
	//save(outputfilename);
	run("Bio-Formats Exporter", "save=["+outputfilename+"] export compression=LZW");
	close();
	
	roiManager("reset");
	
	run("Close All");
}
print("Finished processing");

setBatchMode("show");

eval("script", "System.exit(0);");
