# SOUR Format Docs v 1.2


## Contents:
* Description
* Format Specs
* Installing the Python script to Blender
* Exporting with Blender
* Parsing with Away3D


## Description
SOUR format has the following attributes:
* compressed
* indexed
* vertex animation optional (can be based on a rig or shape keys)
* stores vertices, normals, tangents, uvs, and faces
* at time of writing, has:
    * parser compatible with Away3D 4.0.0 - 4.0.9
    * exporter compatible with patched Blender 2.64
SOUR format does not:
* store cameras, lights, textures, multiple objects, or bones


## Format Specs
SOUR format is compressed using the COMPRESS algorithm. Once uncompressed, the first character of each line tells the parser what to do:
> h		version and model info
> p b0	begin base asset, unanimated
> v		indexed vertex: x,y,z	
> n		indexed vertex normal:	x,y,z
> t		indexed vertex tangent:	x,y,z
> u		indexed uv:	x,y
> f		face consisting of 12 numbers:	v,n,t,u, v,n,t,u, v,n,t,u, 
>> (separate indices for the vert, n,t,and u for each vertex in this triangle- that is, verts, normals, tangents, and uvs are all indexed separately)
	a		attachment point, comma separated, consisting of a name then 6 numbers: head xyz and tail xyz
	p b1	end base asset
	p a0	begin animation (if has animation, otherwise, skip 
				everything between this and "p a1"
	p s0	begin sequence
	l		label ("sequence name")
	p f0	begin frame
	d		duration of frame
	v	
	a		attachment point, as above
	p f1	end frame (Note: frames do not get face info b/c face 
				indices are identical across frames and the base)
	p s1	end sequence (Note: more sequences can be added to the
				animation, just like frames to a sequence)
	p a1	end anim
	


2) Installing the Python script to Blender
To install the SOUR python export script to Blender, the following steps must be taken:
	a) Get or build a copy of Blender with the tangents patch 
	(https://projects.blender.org/tracker/index.php?func=detail&aid=29335&group_id=9&atid=127) 
	applied
	b) Put the io_export_sour.py file in your Blender addons folder. It's at %BLENDER_DIR%/2.xx/scripts/addons
	c) Enable the script in User Preferences


3) Exporting with Blender
To export as .sour:
	a) Select the mesh
	b) Go to File -> Export -> SOUR
	c) If the mesh has animation sequences, each should have a 
		marker with the name of that sequence at its first frame
		and another ending in "_end" at the last frame
	d) If the mesh has animation, check "Export Animation" in the 
		export options, name the file, and export


4) Parsing with Away3D
At the time of writing, SOUR is compatible with Away3D 4.0.7. To use it,:
	a) Either embed or upload a .sour file as you would a text file or any other format (.3ds, .obj, etc.)
	b) AssetLibrary.loadData(something.sour, null, null, new SOURParser());
	c) The parser will hand back a Geometry, and if there's animation, a VertexAnimationState




