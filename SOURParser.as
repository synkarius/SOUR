package com.kumoshi 
{
	import away3d.animators.nodes.VertexClipNode;
	import away3d.animators.VertexAnimationSet;
	import away3d.animators.VertexAnimationState;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.loaders.parsers.ParserBase;
	import away3d.loaders.parsers.ParserDataFormat;
	import away3d.loaders.parsers.utils.ParserUtil;
	import flash.geom.Vector3D;
	import flash.utils.ByteArray;
	
	/**
	 * ...
	 * @author synkarius (dconway1985@gmail.com)
	 */
	public class SOURParser extends ParserBase 
	{
		private var _hasAnim:Boolean;
		private var _hasAttachments:Boolean;
		private var _hasVertexLighting:Boolean;
		private var _hasUVs:Boolean;
		
		private var _autoderiveMissing:Boolean;
		
		private var _isReadingAnim:Boolean;
		
		private var _setupComplete:Boolean;
		private var _baseComplete:Boolean;
		private var _baseFinalized:Boolean;
		private var _animComplete:Boolean;
		private var _animFinalized:Boolean;
		private var _allLinesRead:Boolean;
		private var _allWorkComplete:Boolean;
		
		private var _line:uint;
		private var _lastLine:uint;
		private var _indexer:uint;
		private var _dataArray:Array;
		
		
		private var _indexedVertices:Vector.<Number>;
		private var _indexedNormals:Vector.<Number>;
		private var _indexedTangents:Vector.<Number>;
		private var _indexedUVs:Vector.<Number>;
		
		private var _baseIndices:Vector.<uint>;
		private var _baseVertices:Vector.<Number>;
		private var _baseNormals:Vector.<Number>;
		private var _baseTangents:Vector.<Number>;
		private var _baseUVs:Vector.<Number>;
		
		private var _animIndices:Vector.<uint>;
		private var _animVertices:Vector.<Number>;
		private var _animNormals:Vector.<Number>;
		private var _animTangents:Vector.<Number>;
		private var _animUVs:Vector.<Number>;
		
		private var _baseGeom:Geometry;
		
		private var _name:String;
		
		private var _rounds:uint;
		
		
		private var _seqName:String;
		private var _seqDurations:Vector.<Number>;//data comes in in seconds, 
		private var _seqGeoms:Vector.<Geometry>;
		private var _faceIndsAndTangs:Vector.<uint>;
		private var _vertexAnimSet:VertexAnimationSet;
		
		private var _vertCache:Vector.<String>;
		private var _tangCache:Vector.<String>;
		
		
		private var _attachmentHelper:AttachmentHelper;
		
		/**
		 * 
		 * @param	autoderiveMissingInfo Tells Away3D to autoderive missing normals, tangents, or UVs in animation frames-- if false, it copies that info from the base model instead, which could cause lighting issues
		 */
		public function SOURParser(autoderiveMissingInfo:Boolean=false) 
		{
			super(ParserDataFormat.BINARY);
			
			_line = _indexer = _rounds = 0;
			_autoderiveMissing = autoderiveMissingInfo;
		}
		
		/**
		* @inheritDoc
		* returns MORE_TO_PARSE or PARSING_DONE, sends finished mesh/geom to finalizeAsset(geometry, "name");
		*/
		override protected function proceedParsing():Boolean
		{
			if (!_setupComplete) {
				if (hasTime()) {
					//figure out if is compressed:
					var isCompressed:Boolean = String(_data).substr(0, 10) != "h     SOUR";
					
					var _dataStr:String;
					if (isCompressed) {
						var dataBytes:ByteArray = _data;
						dataBytes.position = 0;
						dataBytes.uncompress();
						_dataStr = dataBytes.toString();
					} else {
						_dataStr = String(_data);
					}
					
					_dataArray = _dataStr.split("\n");
					//_hasAnim = _dataArray.indexOf("p a0") != -1;//set elsewhere
					_lastLine = _dataArray.length - 1;
					_setupComplete = true;
				}
			}
			
			//trace("rounds of parsing: " + _rounds++ + " line, last line: " + _line + ", " + _lastLine);
			
			while (hasTime() && (!_allLinesRead)) {
				parseLine();
				
				if (_line == _lastLine) {
					_allLinesRead = true;
				}
				_line += 1;
			}
			
			if (_baseComplete && (!_baseFinalized)) {
				finalizeAsset(_baseGeom, "");
				
				var  m:Mesh = new Mesh(_baseGeom);
				m.name = _name ||= "";
				finalizeAsset(m);
				
				_baseFinalized = true;
			}
			if (_animComplete && (!_animFinalized)) {
				finalizeAsset(_vertexAnimSet);
				_animFinalized = true;
			}
			if (_allLinesRead && _baseFinalized && (_animFinalized || (!_hasAnim)) ) {
				
				if (_hasAttachments) {
					finalizeAsset(_attachmentHelper);
				}
				
				
				_allWorkComplete = true;
				dispose();
			}
			
			
			
			if (_allWorkComplete) {
				return PARSING_DONE;
			} else {
				return MORE_TO_PARSE;
			}
			
		}
		
		private function parseLine():void {
			
			
			
			
			var _lineType:String = String(_dataArray[_line]).charAt();// .substr(0, 2);
			var _line:String = String(_dataArray[_line]).substring(2);
			var _tempArray:Array = _line.split(",");
			
			
			
			switch(_lineType) {
				case "h":	case " ":	case "\n":	case "":
					break;//ignore header
				case "o":
					_hasAnim = Boolean(int(_tempArray[0] ));
					_hasAttachments = Boolean(int(_tempArray[1] ));
					if (_hasAttachments) {
						_attachmentHelper = new AttachmentHelper();
					}
					_hasVertexLighting = Boolean(int(_tempArray[2] ));
					_hasUVs = Boolean(int(_tempArray[3]));
					break;
				case "i":
					_name = _tempArray[0];
					break;
				case "p":
					processSomething(_line);
					break;
				case "v":
					_indexedVertices.push(Number(_tempArray[0]), Number(_tempArray[1]), Number(_tempArray[2]));
					break;
				case "n":
					_indexedNormals.push(Number(_tempArray[0]), Number(_tempArray[1]), Number(_tempArray[2]));
					break;
				case "t":
					_indexedTangents.push(Number(_tempArray[0]), Number(_tempArray[1]), Number(_tempArray[2]));
					break;
				case "u":
					_indexedUVs.push(Number(_tempArray[0]), Number(_tempArray[1]));
					break;
				case "f":	//a face is vert/tang/v/t/v/t
					//the 3rd-6th arguments here are the destination for whatever's currently in the _indexed<thing> Vectors
					addVertexOfFace(_tempArray, 0, _baseVertices, _baseNormals, _baseTangents, _baseUVs, _baseIndices);
					addVertexOfFace(_tempArray, 1, _baseVertices, _baseNormals, _baseTangents, _baseUVs, _baseIndices);
					addVertexOfFace(_tempArray, 2, _baseVertices, _baseNormals, _baseTangents, _baseUVs, _baseIndices);
					
					
					if (_hasAnim) {
						for (var p:int = 0; p < _tempArray.length; p++) {
							_faceIndsAndTangs.push(uint(_tempArray[p]));
						}
					}
					
					
					break;
					
				case "l":
					_seqName = String(_line);
					break;
				case "d":
					_seqDurations.push(Number(_line));
					break;
				case "a":
					_attachmentHelper.addPoint(
						_tempArray[0], 
						new Vector3D(Number(_tempArray[1]), Number(_tempArray[2]), Number(_tempArray[3])),
						new Vector3D(Number(_tempArray[4]), Number(_tempArray[5]), Number(_tempArray[6])),
						(!_isReadingAnim)?"baseFrame":_seqName,
						(!_isReadingAnim)?0:_seqDurations[_seqDurations.length - 1]);
					break;
				default:	throw new Error("Asset badly formed: " + _lineType); break;
			}
		}
		
		private function processSomething(line:String):void {
			var type:String = line.substr(0, 2);
			switch(type) {
				case "b0"://begin base
					_baseGeom = new Geometry(); 				//create final geometry
					_baseGeom.subGeometries[0] = new SubGeometry();
					_baseIndices = new Vector.<uint>();			//create empty final vectors
					
					_baseVertices = new Vector.<Number>();
					_indexedVertices = new Vector.<Number>();	//create empty temporary vectors for de-indexing
					
					if (_hasVertexLighting) {
						_baseNormals = new Vector.<Number>();
						_indexedNormals = new Vector.<Number>();
						if (_hasUVs) {
							_baseTangents = new Vector.<Number>();
							_indexedTangents = new Vector.<Number>();
						} else {
							_baseGeom.subGeometries[0].autoDeriveVertexTangents = true;
						}
					} else {
						_baseGeom.subGeometries[0].autoDeriveVertexNormals = true;
						_baseGeom.subGeometries[0].autoDeriveVertexTangents = true;
					}
					if (_hasUVs) {
						_baseUVs = new Vector.<Number>();
						_indexedUVs = new Vector.<Number>();
					} else {
						_baseGeom.subGeometries[0].autoGenerateDummyUVs = true;
					}
					
					_faceIndsAndTangs = new Vector.<uint>();//used for animation if animation exists
					
					
					_vertCache = new Vector.<String>();
					_tangCache = new Vector.<String>();
					break;
				case "b1"://end base
					_baseGeom.subGeometries[0].updateIndexData(_baseIndices);
					_baseGeom.subGeometries[0].updateVertexData(_baseVertices);
					if (_hasVertexLighting) {
						_baseGeom.subGeometries[0].updateVertexNormalData(_baseNormals);
						_baseGeom.subGeometries[0].updateVertexTangentData(_baseTangents);
					}
					_baseGeom.subGeometries[0].updateUVData(_baseUVs);
					_baseComplete = true;
					break;
				case "a0"://begin animation
					_vertexAnimSet = new VertexAnimationSet();
					_isReadingAnim = true;
					break;
				case "a1"://end animation
					_animComplete = true;
					break;
				case "s0"://begin animation sequence
					_seqDurations = new Vector.<Number>();
					_seqGeoms = new Vector.<Geometry>();
					break;
				case "s1"://end animation sequence
					var vcn:VertexClipNode = new VertexClipNode();
					for (var f:int = 0; f < _seqGeoms.length; f++) {
						vcn.addFrame(_seqGeoms[f], Number(_seqDurations[f]));
						vcn.fixedFrameRate = false;
					}
					var vas:VertexAnimationState = new VertexAnimationState(vcn);
					_vertexAnimSet.addState(_seqName, vas);
					
					break;
				case "f0"://begin animation frame
					_indexer = 0;
					_indexedVertices = new Vector.<Number>();	//create empty temporary vectors for de-indexing
					break;
				case "f1"://end animation frame
					
					
					var seqSubGeom:SubGeometry = new SubGeometry();
					
					if (!_hasVertexLighting) {
						seqSubGeom.autoDeriveVertexNormals = true;
						seqSubGeom.autoDeriveVertexTangents = true;
					}
					
					_vertCache = new Vector.<String>();
					_tangCache = new Vector.<String>();
					
					if (_autoderiveMissing) {
						seqSubGeom.autoDeriveVertexNormals = true;
						seqSubGeom.autoDeriveVertexTangents = true;
						seqSubGeom.autoGenerateDummyUVs = true;
					}
					
					
					
					_animIndices = _baseIndices;//always the same, they index identically and face-index identically
					_animVertices = new Vector.<Number>();
					
					
					//addvertexofface * 3, add everything (except indices) b/c some things are null
					var fiat:Vector.<uint> = _faceIndsAndTangs;
					for (var y:int = 0; y < fiat.length / 12; y++) {
						//rebuilding fake temparray of face info
						var _tempArray:Array = [fiat[y * 12 + 0], fiat[y * 12 + 1], fiat[y * 12 + 2], fiat[y * 12 + 3], fiat[y * 12 + 4], fiat[y * 12 + 5],
						fiat[y * 12 + 6], fiat[y * 12 + 7], fiat[y * 12 + 8], fiat[y * 12 + 9], fiat[y * 12 + 10], fiat[y * 12 + 11] ];
						addVertexOfFace(_tempArray, 0, _animVertices);
						addVertexOfFace(_tempArray, 1, _animVertices);
						addVertexOfFace(_tempArray, 2, _animVertices);
					}
					
					//if still null & not autoderive, copy from base
					
					if (_hasVertexLighting) {
						if (!_animNormals && !_autoderiveMissing)_animNormals = _baseNormals;
						if (!_animTangents && !_autoderiveMissing)_animTangents = _baseTangents;
						
					}
					if (!_animUVs && !_autoderiveMissing)_animUVs = _baseUVs;
					
					
					seqSubGeom.updateIndexData(_animIndices);
					seqSubGeom.updateVertexData(_animVertices);
					if (_hasVertexLighting) {
						seqSubGeom.updateVertexNormalData(_animNormals);
						seqSubGeom.updateVertexTangentData(_animTangents);
					}
					seqSubGeom.updateUVData(_animUVs);
					
					var seqGeom:Geometry = new Geometry();
					seqGeom.subGeometries[0] = seqSubGeom;
					
					_seqGeoms.push(seqGeom);
					break;
				default: throw new Error("Bad line in asset"); break;
			}
		}
		
		private function addVertexOfFace(ta:Array, ii:int, vertices:Vector.<Number>=null, normals:Vector.<Number>=null, tangents:Vector.<Number>=null, uvs:Vector.<Number> = null, indices:Vector.<uint> = null ):void {
			var vi:uint = ta[4 * ii + 0];
			var ni:uint = ta[4 * ii + 1];
			var ti:uint = ta[4 * ii + 2];
			var ui:uint = ta[4 * ii + 3];
			
			//_faceIndsAndTangs.push(vi, ni, ti, ui);
			
			var flipUVs:int = 1;//used to flip UVs on the y-axis since for some reason, they're upside-down on export
			
			var _thisVertString:String = String(_indexedVertices[vi * 3] + "," + _indexedVertices[vi * 3 + 1] + "," + _indexedVertices[vi * 3 + 2]);
			var _thisTangentString:String = (_hasVertexLighting && _hasUVs)?String(_indexedTangents[ti * 3] + "," + _indexedTangents[ti * 3 + 1] + "," + _indexedTangents[ti * 3 + 2]):"noLighting";
			_thisTangentString += _thisVertString;//important: if we've seen this tangent before WITH THIS INDEX
			if (_vertCache.indexOf(_thisVertString) == -1) {//if we haven't seen this vertex before...
				_vertCache.push(_thisVertString);//...add it...
				_tangCache.push(_thisTangentString);
				
				if(indices)indices.push(_indexer++);
				if(vertices)vertices.push(_indexedVertices[vi*3], _indexedVertices[vi*3+1], _indexedVertices[vi*3+2]);
				if(normals && _hasVertexLighting)normals.push(_indexedNormals[ni*3], _indexedNormals[ni*3+1], _indexedNormals[ni*3+2]);
				if(tangents && _hasVertexLighting)tangents.push(_indexedTangents[ti*3], _indexedTangents[ti*3+1], _indexedTangents[ti*3+2]);
				if(uvs)uvs.push(_indexedUVs[ui*2], flipUVs-_indexedUVs[ui*2+1]);
			} else {//we have seen this vert before
				if (_tangCache.indexOf(_thisTangentString) == -1) { //but what about the vert with this tangent? if not...
					_tangCache.push(_thisTangentString);
					
					if(indices)indices.push(_indexer++);
					if(vertices)vertices.push(_indexedVertices[vi*3], _indexedVertices[vi*3+1], _indexedVertices[vi*3+2]);
					if(normals)normals.push(_indexedNormals[ni*3], _indexedNormals[ni*3+1], _indexedNormals[ni*3+2]);
					if(tangents)tangents.push(_indexedTangents[ti*3], _indexedTangents[ti*3+1], _indexedTangents[ti*3+2]);
					if(uvs)uvs.push(_indexedUVs[ui*2], flipUVs-_indexedUVs[ui*2+1]);
				} else {//we have also seen this vert before
					if(indices)indices.push(_tangCache.indexOf(_thisTangentString));
				}
			}
			
			
			
		}
		
		
		
		
		
		
		
		
		public function dispose():void {
			_attachmentHelper = null;
			
			_dataArray = null;
			
			_indexedVertices = null;
			_indexedNormals = null;
			_indexedTangents = null;
			_indexedUVs = null;
			
			_baseIndices = null;
			_baseVertices = null;
			_baseNormals = null;
			_baseTangents = null;
			_baseUVs = null;
			
			_animIndices = null;
			_animVertices = null;
			_animNormals = null;
			_animTangents = null;
			_animUVs = null;
			
			_baseGeom = null;
			
			_seqName = null;
			_seqDurations = null;
			_seqGeoms = null;
			_faceIndsAndTangs = null;
			_vertexAnimSet = null;
			
			_vertCache = null;
			_tangCache = null;
		}
		
		
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension:String):Boolean
		{
			extension = extension.toLowerCase();
			return extension == "sour";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data:*):Boolean
		{
			var content:String = ParserUtil.toString(data);
			var hasV:Boolean;
			var hasB:Boolean;
			var hasCompressed:Boolean;
			
			if (content) {
				hasB = content.indexOf("p b0") != -1;
				hasV = content.indexOf("v") != -1;
				hasCompressed = content.indexOf("xœ¤") != -1;
			}
			
			return (hasV && hasB) || hasCompressed;
		}
		
	}
	

}