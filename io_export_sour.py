# ##### BEGIN GPL LICENSE BLOCK #####
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation,
#  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# ##### END GPL LICENSE BLOCK #####

bl_info = {
    "name": "Export SOUR(.sour)",
    "author": "David Conway (synkarius)",
    "version": (0, 4),
    "blender": (2, 6, 4),
    "api": 51232,
    "location": "File > Export > SOUR Format (.sour)",
    "description": "Export as SOUR Format (.sour)",
    "warning": "",
    "wiki_url": "none yet",
    "tracker_url": "none yet",
    "category": "Import-Export"}


import bpy
from bpy.props import *
from bpy_extras.io_utils import ExportHelper
import zlib


###### EXPORT OPERATOR #######
class Export_sour(bpy.types.Operator, ExportHelper):
    '''Exports the selected object as a SOUR file.'''
    bl_idname = "export_sour.ts"
    bl_label = "Export SOUR (.sour)"

    filename_ext = ".sour"

    export_anim = BoolProperty(name="Animation",
        description="Exports Animation Data",
        default=False,
    )
    export_anim_verts_only = BoolProperty(name="Anim Verts Only",#currently makes no difference(v0.43)
        description="Only export vertices for Animation",
        default=True,
    )
    export_normals = BoolProperty(name="Export Vertex Normals",
        description="",
        default=True,
    )
    export_tangents = BoolProperty(name="Export Vertex Tangents",
        description="",
        default=True,
    )
    export_uvs = BoolProperty(name="Export UVs",
        description="",
        default=True,
    )
    

    

    def writeVertexAnimated(self, baseModel, filename, sequences=None):
        
        outString = ""
        outString += "h     SOUR Format 0.43\n"
        outString += "h     mi: "+str(baseModel[5])+"   mt: " + str(baseModel[6])+"   mf: " + str(baseModel[7])+"\n\n"
        outString += "o " + str(int(self.export_anim))+","+str(int(self.export_anim_verts_only))+","+str(int(self.export_normals))+","+str(int(self.export_tangents))+","+str(int(self.export_uvs))+"\n\n"
        outString += "p b0"+"\n\n"
        outString += baseModel[0]+"\n\n"
        outString += baseModel[1]+"\n\n"
        outString += baseModel[2]+"\n\n"
        outString += baseModel[3]+"\n\n"
        outString += baseModel[4]+"\n\n"
        outString += "p b1"+"\n\n"
        
        if sequences:
            outString += "p a0\n\n"
            for s in range(0,len(sequences)):
                seq = sequences[s]
                outString += "p s0"+"\n\n"
                outString += "l " + str(seq[0])+"\n\n"#name
                for f in range (1,len(seq)):
                    position = f%2
                    if position == 1:
                        outString += "p f0"+"\n\n"
                        outString += "d " + str(seq[f])+"\n\n"
                    if position == 0:
                        outString += seq[f]+"\n\n"
                        outString += "p f1"+"\n\n"#goes on the last "position" in each frame
                outString += "p s1"+"\n\n"#close sequence
            outString += "p a1\n\n"
                    
                
        
        data = zlib.compress(bytes(outString, 'UTF-8'))
        outfile = open(filename, "wb")#, encoding="utf8", newline="\n")
        outfile.write(data)#outString)
        outfile.close()
    
      
    def createAnimation(self, _mesh):
        #figure out if we're using armature keyframes or mesh keyframes
        
        
        #get the mesh as an object:
        mesh = bpy.context.scene.objects.active
        
        armature = mesh.find_armature()
        if armature != None:
           mesh.select = False
           armature.select = True
           bpy.context.scene.objects.active = armature
        
        #figure out how many animations there are (markers), list their names and their start/end times
        markers = bpy.context.scene.timeline_markers
        
        names = []
        starts = []
        ends = []
        allKeyframes = []
        allKeyframeDurations = []
        
        for m in range(0, len(markers)):
            if markers[m].name[-4:] != "_end":#convention: sequences are ended with "_end"
                names.append(markers[m].name)
                starts.append(markers[m].frame)
            else:
                ends.append(markers[m].frame)
            
            
        firstFrame = bpy.context.scene.frame_start
        bpy.context.scene.frame_set(firstFrame)
        result = None
        allKeyframes.append(bpy.context.scene.frame_current)
        while result.__repr__() != "{'CANCELLED'}":
            result = bpy.ops.screen.keyframe_jump(next=True)
            currentFrame = bpy.context.scene.frame_current
            if currentFrame not in allKeyframes:
                allKeyframes.append(currentFrame)
        
        numKeyframes = len(allKeyframes)
        
        for k in range(0, numKeyframes):
            #if k != 0:#the first frame has no duration; it is the same as the last frame
            if k == numKeyframes-1:#the last frame has 0 duration, since it is also the first frame or the destination
                allKeyframeDurations.append(0)
            else:
                allKeyframeDurations.append(allKeyframes[k+1]-allKeyframes[k])
            
        
        
        
        
        #use the set and jump commands to move through the timeline, checking if we're past the current n/s/e index
        animIndex = 0
        nameIndex = 0  
        
        
        sequences = []
        seq = None
        #sequences structure: [ [name, duration, verts, norms, tangs, uvs  d, v, n, t, u, d, v, n, t, u, ...][][][] ]
        for h in range(0,len(allKeyframes)):
            bpy.context.scene.frame_set(allKeyframes[h])#assumes the markers are set on frame 0 of each animation sequence
            if allKeyframes[h] in starts:
                seq = []
                seq.append(names[nameIndex])
                nameIndex += 1
            seq.append(allKeyframeDurations[h])
            
            meshGeo = mesh.to_mesh(bpy.context.scene, True, 'PREVIEW')
            animBase = self.createVertexAnimBase(meshGeo)#0 verts, 1 norms, 2 tangents
            
            seq.append(animBase[0])#verts
            #seq.append(animBase[1])#normals#TODO: allow these to be added to animation frames
            #seq.append(animBase[2])#tangs
            #seq.append(animBase[3])#uvs
            #seq.append(animBase[4])#faces
            
            #sequences.append([names[h]])
            
            if allKeyframes[h] in ends:
                sequences.append(seq)
        
        
        
        return sequences
        
    def extractInfoFromVert(self, mesh, currFace, currVert, vertexCache, normalCache, tangentCache, uvCache, vIndex, nIndex, tIndex, uIndex):
        vertex = mesh.vertices[ mesh.tessfaces[currFace].vertices[currVert] ].co
        normal = mesh.tangent_space.vertices[ mesh.tangent_space.tessfaces[currFace].vertices[currVert] ].normal
        tangent = mesh.tangent_space.vertices[ mesh.tangent_space.tessfaces[currFace].vertices[currVert] ].tangent
        uv = mesh.tessface_uv_textures.active.data[currFace].uv[currVert] if mesh.tessface_uv_textures.active else None
        
        vpx,vpy,vpz = vertex
        vnx,vny,vnz = normal
        vtx,vty,vtz = tangent
        if uv:
            vux,vuy = uv
        else:
            vux,vuy = 0,0
        
        vertexStr = "v " + str(vpx)+","+str(vpy)+","+str(vpz)
        normalStr = "n " + str(vnx)+","+str(vny)+","+str(vnz)
        tangentStr = "t " + str(vtx)+","+str(vty)+","+str(vtz)
        uvStr = "u " + str(vux)+","+str(vuy)
        
        currFacePartialData = ""
        
        #results:
        rv = None#result vertex
        rn = None
        rt = None
        ru = None
        rcpfd = ""
        
        if not vertexStr in vertexCache:
            vertexCache.append(vertexStr)
            rcpfd += str(vIndex)
            rv = vertexStr
           #rn = normalStr
            vIndex += 1
        else:
            rcpfd += str(vertexCache.index(vertexStr))
            
        rcpfd += ","#separate vertex index from tangent index in pair
        
        if not normalStr in normalCache:
            normalCache.append(normalStr)
            rcpfd += str(nIndex)
            rn = normalStr
            nIndex += 1
        else:
            rcpfd += str(normalCache.index(normalStr))
            
        rcpfd += ","
        
        if not tangentStr in tangentCache:
            tangentCache.append(tangentStr)
            rcpfd += str(tIndex)
            rt = tangentStr
            #ru = uvStr
            tIndex += 1
        else:#
            rcpfd += str(tangentCache.index(tangentStr))
            
        rcpfd += ","
        
        if not uvStr in uvCache:
            uvCache.append(uvStr)
            rcpfd += str(uIndex)
            ru = uvStr
            uIndex += 1
        else:#
            rcpfd += str(uvCache.index(uvStr))
            
        return [rv, rn, rt, ru, rcpfd, vIndex, nIndex, tIndex, uIndex]
    
    def createVertexAnimBase(self, mesh):
        vertexData = ""
        normalData = ""
        tangentData = ""
        uvData = ""
        faceData = ""
        
        vertexCache = []# a list of str()'d vertices used to figure out what's been indexed already as you go through the list
        normalCache = []
        tangentCache = []
        uvCache = []
        numfaces = 0
        
        #currIndex = 0#used for indices list
        #currTangentIndex = 0
        vIndex = 0
        nIndex = 0
        tIndex = 0
        uIndex = 0
        
        lastFace = len(mesh.tessfaces) - 1
        
        for currFace in range(0,len(mesh.tessfaces)):
            currFaceData = []#[None,None,None,None,None,None]#index x,y,z, tangent index x,y,z
            
            faceData += "f "
            
            thisFaceIsAQuad = len(mesh.tessfaces[currFace].vertices)==4
            
            indicesInFace = [0,1,2]
            for currVert in indicesInFace:#range(0,len(mesh.tessfaces[currFace].vertices)):
                #reinsert stuff here
                extr = self.extractInfoFromVert(mesh, currFace, currVert, vertexCache, normalCache, tangentCache, uvCache, vIndex, nIndex, tIndex, uIndex)
                if extr[0]:
                    if len(vertexData)>0:
                        vertexData += "\n"
                        #normalData += "\n"
                    vertexData += extr[0]
                    #normalData += extr[1]
                
                if extr[1]:
                    if len(normalData)>0:
                        normalData += "\n"
                    normalData += extr[1]
                
                if extr[2]:
                    if len(tangentData)>0:
                        tangentData += "\n"
                        #uvData += "\n"
                    tangentData += extr[2]
                    #uvData += extr[3]
                
                if extr[3]:
                    if len(uvData)>0:
                        uvData += "\n"
                    uvData += extr[3]
                
                faceData += extr[4]
                if currVert == indicesInFace[0] or currVert == indicesInFace[1]:
                    faceData += ","
                elif currVert == indicesInFace[2] and currFace != lastFace:
                    faceData += "\n"
                elif currVert == indicesInFace[2] and currFace == lastFace and thisFaceIsAQuad:
                    faceData += "\n"
                vIndex = extr[5]
                nIndex = extr[6]
                tIndex = extr[7]
                uIndex = extr[8]
            numfaces += 1
            
            if thisFaceIsAQuad:
                faceData += "f "
                
                indicesInFace = [0,2,3]
                for currVert in indicesInFace:#range(0,len(mesh.tessfaces[currFace].vertices)):
                    #reinsert stuff here
                    extr = self.extractInfoFromVert(mesh, currFace, currVert, vertexCache, normalCache, tangentCache, uvCache, vIndex, nIndex, tIndex, uIndex)
                    if extr[0]:
                        if len(vertexData)>0:
                            vertexData += "\n"
                            #normalData += "\n"
                        vertexData += extr[0]
                        #normalData += extr[1]
                    
                    if extr[1]:
                        if len(normalData)>0:
                            normalData += "\n"
                        normalData += extr[1]
                    
                    if extr[2]:
                        if len(tangentData)>0:
                            tangentData += "\n"
                            #uvData += "\n"
                        tangentData += extr[2]
                        #uvData += extr[3]
                    
                    if extr[3]:
                        if len(uvData)>0:
                            uvData += "\n"
                        uvData += extr[3]
                    
                    faceData += extr[4]
                    if currVert == indicesInFace[0] or currVert == indicesInFace[1]:
                        faceData += ","
                    elif currVert == indicesInFace[2] and currFace != lastFace:
                         faceData += "\n"
                    vIndex = extr[5]
                    nIndex = extr[6]
                    tIndex = extr[7]
                    uIndex = extr[8]
                numfaces += 1
            
            
        return [vertexData,normalData,tangentData,uvData,faceData, len(vertexCache), len(tangentCache), numfaces]        


    @classmethod
    def poll(cls, context):
        return True

    def execute(self, context):
        props = self.properties
        filepath = self.filepath
        filepath = bpy.path.ensure_ext(filepath, self.filename_ext)

        mesh = bpy.context.scene.objects.active.to_mesh(bpy.context.scene, True, 'PREVIEW')
        frames = self.createAnimation(mesh) if self.export_anim else None
        self.writeVertexAnimated(self.createVertexAnimBase(mesh), filepath, frames)

        return {'FINISHED'}

    def invoke(self, context, event):
        wm = context.window_manager

        if True:
            # File selector
            wm.fileselect_add(self) # will run self.execute()
            return {'RUNNING_MODAL'}
        elif True:
            # search the enum
            wm.invoke_search_popup(self)
            return {'RUNNING_MODAL'}
        elif False:
            # Redo popup
            return wm.invoke_props_popup(self, event)
        elif False:
            return self.execute(context)


### REGISTER ###

def menu_func(self, context):
    self.layout.operator(Export_sour.bl_idname, text="SOUR (.sour)")


def register():
    bpy.utils.register_module(__name__)

    bpy.types.INFO_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_module(__name__)

    bpy.types.INFO_MT_file_export.remove(menu_func)

if __name__ == "__main__":
    register()
