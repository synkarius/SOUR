package com.kumoshi
{
	import away3d.animators.VertexAnimator;
	import away3d.containers.ObjectContainer3D;
	import away3d.core.base.Geometry;
	import away3d.entities.Mesh;
	import away3d.library.assets.IAsset;
	import away3d.library.assets.NamedAssetBase;
	import flash.geom.Vector3D;
	import flash.utils.Dictionary;
	import flash.utils.getTimer;
	import away3d.library.assets.AssetType;
	/**
	 * ...
	 * @author dave
	 */
	public class AttachmentHelper extends NamedAssetBase implements IAsset
	{
		private var _setupPointNames:Vector.<String>;	//the first (0-th) is for the base
		private var _heads:Vector.<Vector3D>;
		private var _tails:Vector.<Vector3D>;
		
		private var _setupSeqNames:Vector.<String>;
		private var _durations:Vector.<Number>;
		
		private var _indexesDirty:Boolean;
		private var _seqDict:Dictionary;
		private var _seqNames:Vector.<String>;
		private var _setupSeqLengths:Vector.<Number>;//[name
		private var _pointNames:Vector.<String>;
		//private var _animator:VertexAnimator;
		
		private var _lastTimer:int;
		
		private var _data:Vector.<Number>;
		
		public function AttachmentHelper() 
		{
			_setupPointNames = new Vector.<String>();
			_heads = new Vector.<Vector3D>();
			_tails = new Vector.<Vector3D>();
			
			_setupSeqNames = Vector.<String>([]);//to keep the offset
			_durations = Vector.<Number>([]);
			
			_seqDict = new Dictionary();
			_seqNames = new Vector.<String>();
			_setupSeqLengths = new Vector.<Number>();
			_pointNames = new Vector.<String>();
			_data = new Vector.<Number>();
			
			
			
		}
		
		public function dispose():void {
			_setupPointNames = null;
			_heads = null;
			_tails = null;
			
			_setupSeqNames = null;
			_durations = null;
			
			_seqDict = null;
			_seqNames = null;
			_setupSeqLengths = null;
			_pointNames = null;
		}
		
		
		public function addPoint(name:String, head:Vector3D, tail:Vector3D, seqName:String = null, frameDur:Number = -1):void {
			_setupPointNames.push(name);
			_heads.push(head);
			_tails.push(tail);
			if (frameDur != -1) {
				_indexesDirty = true;//if a non-base frame, it needs to be time-indexed before continuing
				_setupSeqNames.push(seqName);
				_durations.push(frameDur);
			}
		}
		
		
		
		private function processSequences():void {//HEAVY
			//var pM:Mesh = new Mesh(new Geometry());//"positioning Mesh"//optimize mode, broken
			
			
			for (var i:int = 1; i < _setupSeqNames.length; i++) {
				var pointSeqCombo:String = _setupPointNames[i] + _setupSeqNames[i];
				if (!_seqDict[pointSeqCombo]) {//if there is no sequence/point entry already for  this sequence/point combo,
					_seqDict[pointSeqCombo] = [];//... make one
				}
				
				//if (_durations[i] != 0){//if not the last (stitched) frame:
					//pM.position = _heads[i];//optimize mode, broken
					//pM.lookAt(_tails[i]);//optimize mode, broken
					
					
					//each frame is an array: [head, rotationXYZ, duration]
					_seqDict[pointSeqCombo].push([_heads[i], 
					//_seqDict[pointSeqCombo].push([pM.position, //optimize mode, broken
						//new Vector3D(pM.rotationX,pM.rotationY,pM.rotationZ),//optimize mode, broken
						_tails[i],//testing mode 
						_durations[i]]
						);
				//}
				
				if (_seqNames.indexOf(_setupSeqNames[i]) == -1) {//get a list of sequence names and set up for sequence lengths if needed
					_seqNames.push(_setupSeqNames[i]);
					_setupSeqLengths.push(0);
				}
				_setupSeqLengths[_seqNames.indexOf(_setupSeqNames[i])] += _durations[i];
				
				
				
				if (_pointNames.indexOf(_setupPointNames[i])==-1) {//get a list of point names
					_pointNames.push(_setupPointNames[i]);
				}
				
				
				
			}
			
			for (var h:int = 0; h < _seqNames.length; h++) {//so I don't have to do indexOf() later, a dictionary of sequence lengths
				_seqDict[_seqNames[h] + "len"] = _setupSeqLengths[h]/_pointNames.length;
			}
			
			
			
		}
		
		
		private function getPosRot(seqName:String, pointNames:Vector.<String>):Vector.<Number> { 
			if (_indexesDirty) {
				processSequences();
				_indexesDirty = false;
			}
			
			
			
			var point_sequence:Array = _seqDict[pointNames[0] + seqName];//the array of frames for this sequence & a-point
			if (!point_sequence) {
				throw new Error("invalid point / sequence combo in Attachment Helper: " + pointNames[0] + seqName);
			}
			
			//FIND WHICH TWO FRAMES WE'RE BETWEEN NOW
			var timePassed:uint = getTimer() - _lastTimer;//time since "play" was pressed
			var seqTotalTime:uint = uint(_seqDict[seqName + "len"]);
			var sequenceTime:uint = timePassed % seqTotalTime; // milliseconds into this cycle of this sequence
			var currentFrame:int;//the last Blender keyframe which was passed
			var nextFrame:int;//the next to be passed
			var totalTime:int = 0;
			var start:Number;
			var end:Number;
			intervalLoop: for (var i:int = 0; i < point_sequence.length; i++) {
				var dur:Number = (point_sequence[i][2] as Number).valueOf();
				
				start = totalTime.valueOf();
				totalTime += dur;
				end = totalTime.valueOf();
				
				if ((sequenceTime>=start) && (sequenceTime<=end)) {
					currentFrame = i;
					nextFrame = i + 1;
					if (nextFrame == point_sequence.length) nextFrame = 0;
					
					break intervalLoop;
				} 
			}
			
			
			var fraction:Number = (sequenceTime-start) / (end - start);
			var result:Vector.<Number> = new Vector.<Number>();
			
			for (var k:int = 0; k < pointNames.length; k++) {
				point_sequence = _seqDict[pointNames[k] + seqName];
				var curPos:Vector3D = (point_sequence[currentFrame][0] as Vector3D).clone();
				var curRot:Vector3D = (point_sequence[currentFrame][1] as Vector3D).clone();
				var nxtPos:Vector3D = (point_sequence[nextFrame][0] as Vector3D).clone();
				var nxtRot:Vector3D = (point_sequence[nextFrame][1] as Vector3D).clone();
				
				
				
				result.push(
				(nxtPos.x-curPos.x)*fraction+curPos.x,//new position
				(nxtPos.y-curPos.y)*fraction+curPos.y,
				(nxtPos.z-curPos.z)*fraction+curPos.z,
				(nxtRot.x-curRot.x)*fraction+curRot.x,//new rotation-lookat point
				(nxtRot.y-curRot.y)*fraction+curRot.y,
				(nxtRot.z-curRot.z)*fraction+curRot.z
				);
				
				
			}
			return result;
		}
		
		/**
		 * Tracks the time relative to the beginning of an animation sequence, should be called at the same time the animation is played
		 * @param	sequence The name of the animation sequence
		 */
		public function play(sequence:String):void {
			_lastTimer = getTimer();
		}
		
		/**
		 * Updates the attachment data for the given attachment points and animation sequence
		 * @param	sequence
		 * @param	points
		 */
		public function update(sequence:String, points:Vector.<String>):void {
			_data = getPosRot(sequence, points);
		}
		
		/**
		 * Returns a Vector of [x,y,z,rx,ry,rz, ...] for the last updated sequence and points
		 */
		public function get data():Vector.<Number> {
			return _data;
		}
		
		public function get assetType() : String		{
			return AssetType.ENTITY;
		}
		
	}

}