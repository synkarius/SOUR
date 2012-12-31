# SOUR Format Docs v 1.2


## Contents:
* Description
* Format Specs
* Installing the Python script to Blender
* Exporting with Blender
* Parsing with Away3D
* Attachments


## Description
SOUR format has the following features:
* indexed
* optional compression
* optional vertex animation (can be based on a rig, shape keys, or both)
* optional attachment points (see section titled "attachment points")
* stores vertices, normals, tangents, uvs, and faces (normals and tangents optional)
* at time of writing, has:
    * parser compatible with Away3D 4.0.0 - 4.0.9
	* exporter compatible with patched Blender 2.64
    * AttachmentHelper.as AS3 class to assist with using attachment data

SOUR format does not:
* store cameras, lights, textures, multiple objects, or bones


## Format Specs
SOUR format is compressed using the COMPRESS algorithm. Once uncompressed, the first character of each line tells the parser what to do:

* h	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;version and model info  
* p b0  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;begin base asset, unanimated  
* v	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;indexed vertex: x,y,z  
* n	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;indexed vertex normal:	x,y,z  
* t	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;indexed vertex tangent:	x,y,z  
* u	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;indexed uv:	x,y  
* f	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;face consisting of 12 numbers:	v,n,t,u, v,n,t,u, v,n,t,u, (separate indices for the vert, n,t,and u for each vertex in this triangle- that is, verts, normals, tangents, and uvs are all indexed separately)  
* a	    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;attachment point, comma separated, consisting of a name then 6 numbers: head xyz and tail xyz  
* p b1  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;end base asset  
* p a0  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;begin animation (if has animation, otherwise, skip everything between this and "p a1"  
* p s0  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;begin sequence  
* l     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;label ("sequence name")  
* p f0  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;begin frame  
* d     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;duration of frame  
* v	 
* a     &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;attachment point, as above  
* p f1  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;end frame (Note: frames do not get face info b/c face indices are identical across frames and the base)  
* p s1  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;end sequence (Note: more sequences can be added to the animation, just like frames to a sequence)  
* p a1  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;end anim  
	


## Installing the Python script to Blender
To install the SOUR python export script to Blender, the following steps must be taken:
* Get or build a copy of Blender with the tangents patch https://projects.blender.org/tracker/index.php?func=detail&aid=29335&group_id=9&atid=127 applied
* Put the io_export_sour.py file in your Blender addons folder. It's at %BLENDER_DIR%/2.xx/scripts/addons
* Enable the script in User Preferences


## Exporting with Blender
To export as .sour:
* Select the mesh
* Go to File -> Export -> SOUR
* If the mesh has animation sequences, each should have a marker with the name of that sequence at its first frame and another ending in "_end" at the last frame
* If the mesh has animation, check "Export Animation" in the export options, name the file, and export


## Parsing with Away3D
At the time of writing, SOUR is compatible with Away3D 4.0.7. To use it,:
* Either embed or upload a .sour file as you would a text file or any other format (.3ds, .obj, etc.)
* AssetLibrary.loadData(sour_data, null, null, new SOURParser());
* The parser will hand back a Geometry, if there's animation, a VertexAnimationState, and if there are attachment points, an AttachmentHelper

## Attachment Points
You can designate bones in the selected Mesh's Armature in Blender as "attachment points" by using the following naming convention:
* "_attach_to_" before the name of the bone
* if using attachment points, the armature must have a root bone named "root" at 0,0,0 which all other bones or their parents/grandparents/etc are parented to
* the "root" bone must have no rotations applied during any animation sequence

When you export a SOUR file with attachment points and import it into Away3D, SOURParser will return an AttachmentHelper. 
* AttachmentHelper's play() function should be called at the same time as the VertexAnimator's play() function for animation if attachments to stay sync'd.
* AttachmentHelper's update() function should be called once per render for smooth animation. It updates the positions of all attachment points whose Blender bone names are entered as parameters. 
    * A bone named "_attach_to_head" (no quotes) in Blender would be passed as just "head" to update(). The naming convention is stripped in the parser.
* After update() has been called, a Vector<Number> can be retrieved via the .data getter. It is the x,y,z of each head, then the x,y,z of each tail for each attachment point entered in update(), in the same order they were entered into update().
    * So if I called update as update("walk",Vector(["hand","head"]), I would get back a Vector<Number> with 6 numbers for the hand, then 6 for the head, all for the current frame of the animation sequence.
	* How you handle that information from there is up to you. I'd suggest a simple ".position = " for the first three numbers of every six, and a ".lookAt()" for the second three.


