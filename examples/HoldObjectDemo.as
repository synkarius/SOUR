package 
{
	import away3d.animators.VertexAnimator;
	import away3d.animators.VertexAnimationSet;
	import away3d.cameras.Camera3D;
	import away3d.containers.ObjectContainer3D;
	import away3d.containers.Scene3D;
	import away3d.containers.View3D;
	import away3d.core.base.Geometry;
	import away3d.debug.AwayStats;
	import away3d.entities.Mesh;
	import away3d.lights.DirectionalLight;
	import away3d.materials.ColorMaterial;
	import away3d.materials.lightpickers.StaticLightPicker;
	import away3d.materials.TextureMaterial;
	import away3d.primitives.SphereGeometry;
	import away3d.textures.BitmapTexture;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import away3d.library.AssetLibrary;
	import away3d.events.AssetEvent;
	import away3d.library.assets.AssetType;
	import away3d.loaders.parsers.OBJParser;
	import flash.events.MouseEvent;
	import flash.geom.Vector3D;
	import flash.text.TextField;
	
	import com.kumoshi.SOURParser;
	import com.kumoshi.AttachmentHelper;
	
	/**
	 * ...
	 * @author synkarius
	 */
	[SWF(width = "400", height = "300", frameRate = "60", backgroundColor = "0xffffff")]
	public class HoldObjectDemo extends Sprite 
	{
		private var _view:View3D;
		private var _scene:Scene3D;
		private var _cam:Camera3D;
		
		private var _lp:StaticLightPicker;
		private var _dl:DirectionalLight;
		
		private var _geo:Geometry;
		private var _ani:VertexAnimationSet;
		private var _atc:AttachmentHelper;
		
		private var _womanOC3D:ObjectContainer3D;
		private var _woman:Mesh;
		private var _animator:VertexAnimator;
		private var _heldObjectOC3D:ObjectContainer3D;
		
		private var _hasBegun:Boolean;
		
		private var _curtain:Sprite;
		private var _render:Boolean;
		private var _awaystats:AwayStats;
		
		private var _bat:Mesh;
		private var _sword:Mesh;
		
		[Embed(source="../lib/alice.n.png")]private var _normal:Class;
		[Embed(source="../lib/alice.d.jpg")]private var _diffuse:Class;
		[Embed(source = "../lib/alice.sour", mimeType = "application/octet-stream")]private var _womanData:Class;
		
		[Embed(source="../lib/bat.sour", mimeType="application/octet-stream")]private var _batData:Class;
		[Embed(source="../lib/batDiffuse.png")]private var _batDiffuse:Class;
		[Embed(source="../lib/sword.sour", mimeType="application/octet-stream")]private var _swordData:Class;
		[Embed(source="../lib/swordDiffuse.jpg")]private var _swordDiffuse:Class;
		
		
		private var _headBall:Mesh;
		private var _tailBall:Mesh;
		
		public function HoldObjectDemo():void 
		{
			init3D();
			demoStuff();
			
			_heldObjectOC3D = new ObjectContainer3D();
			_headBall = new Mesh(new SphereGeometry(.5), new ColorMaterial(0xbf0000));
			_tailBall = new Mesh(new SphereGeometry(.5), new ColorMaterial(0x0000EE));
			
			
			AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onParseWomanComplete,false,0,true);
			AssetLibrary.loadData(new _womanData(),null,null,new SOURParser());
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
			addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
			addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
			addEventListener(MouseEvent.CLICK,onMouseClick);
		}
		
		private function onMouseClick(e:MouseEvent):void {
			
			_animator.play("wave");//_animator.play() and _atc.play() need to be called at the same time for them to be sync'd up
			_atc.play("wave");
			
			if (_bat && _sword) {
				if (_heldObjectOC3D.contains(_bat)) {
					_heldObjectOC3D.removeChild(_bat);
					_heldObjectOC3D.addChild(_sword);
				} else if (_heldObjectOC3D.contains(_sword)) {
					_heldObjectOC3D.removeChild(_sword);
				} else {
					_heldObjectOC3D.addChild(_bat);
				}
			}
			
			
			
			
		}
		
		private function onMouseOver(e:MouseEvent):void {
			_curtain.alpha = 0;
			_render = true;
			addChild(_awaystats);
		}
		private function onMouseOut(e:MouseEvent):void {
			_curtain.alpha = .8;
			_render = false;
			removeChild(_awaystats);
		}
		
		private function onAnimStop():void {
			
		}
		
		private function onEnterFrame(e:Event):void {
			if (_render) {
				if (!_hasBegun && _atc) {
					_animator.play("wave");//_animator.play() and _atc.play() need to be called at the same time for them to be sync'd up
					_atc.play("wave");
					_hasBegun = true;
				}
				
				if (_hasBegun) {
					_atc.update("wave", Vector.<String>(["hand.L"]));
					var _data:Vector.<Number> = _atc.data;
					_heldObjectOC3D.position = new Vector3D( _data[0], _data[1],_data[2]);
					_heldObjectOC3D.lookAt(new Vector3D( _data[3], _data[4],_data[5]));
					
					_headBall.position = new Vector3D( _data[0], _data[1],_data[2]);
					_tailBall.position = new Vector3D( _data[3], _data[4],_data[5]);
					
					_womanOC3D.rotationY += .1;
				}
				
				_view.render();
			} 
			
			
		}
		
		private function onParseObject(e:AssetEvent):void {
			var _tm:TextureMaterial;
			if (!_bat) {
				_tm = new TextureMaterial(new BitmapTexture(new _batDiffuse().bitmapData));
				_tm.lightPicker = _lp;
				_bat = new Mesh(e.asset as Geometry, _tm);
				AssetLibrary.loadData(new _swordData(), null, null, new SOURParser());
				trace("got geometry: bat");
			} else {
				_tm = new TextureMaterial(new BitmapTexture(new _swordDiffuse().bitmapData));
				_tm.lightPicker = _lp;
				_sword = new Mesh(e.asset as Geometry, _tm);
				AssetLibrary.removeEventListener(AssetEvent.ASSET_COMPLETE, onParseObject);
				trace("got geometry: sword");
			}
		}
		
		private function onParseWomanComplete(e:AssetEvent):void {
			switch(e.asset.assetType) {
				case AssetType.GEOMETRY: 
					_geo = e.asset as Geometry; 
					trace("got geometry: woman");
					break;
				case AssetType.ANIMATION_SET: 
					_ani = e.asset as VertexAnimationSet;
					trace("got animation: woman");
					break;
				case AssetType.ENTITY: 
					_atc = e.asset as AttachmentHelper;
					trace("got attachment point(s): woman");
					break;
				case AssetType.MESH:
					trace("mesh name: " + (e.asset as Mesh).name);
					//the parser returns a named mesh too, but it's not being used in this example
					break;
				default: throw new Error("unknown thing got parsed by SOURParser: " + e.asset.assetType); break;
			}
			
			if (_geo && _ani && _atc) {
				AssetLibrary.removeEventListener(AssetEvent.ASSET_COMPLETE, onParseWomanComplete);
				constructWoman();
			}
		}
		
		
		
		private function constructWoman():void {
			var _tm:TextureMaterial = new TextureMaterial(new BitmapTexture(new _diffuse().bitmapData));
			var _normals:BitmapTexture = new BitmapTexture(new _normal().bitmapData);
			_tm.lightPicker = _lp;
			_tm.normalMap = _normals;
			_tm.specular = .1;
			
			_animator = new VertexAnimator(_ani);
			
			_woman = new Mesh(_geo, _tm);
			_woman.animator = _animator;
			_womanOC3D = new ObjectContainer3D();
			_womanOC3D.addChild(_woman);
			_womanOC3D.addChild(_heldObjectOC3D);
			_womanOC3D.y = 15;
			_scene.addChild(_womanOC3D);
			_view.render();
			
			_womanOC3D.addChild(_headBall);
			_womanOC3D.addChild(_tailBall);
			
			AssetLibrary.addEventListener(AssetEvent.ASSET_COMPLETE, onParseObject,false,0,true);
			AssetLibrary.loadData(new _batData(),null,null,new SOURParser());
		}
		
		private function init3D():void {
			_cam = new Camera3D();
			_cam.moveTo(0,35,35);
			_cam.lookAt(new Vector3D(0,30,0));
			_scene = new Scene3D();
			_view = new View3D(_scene, _cam);
			_view.antiAlias = 4;
			_view.backgroundColor = 0x7F7F7F;
			addChild(_view);
			
			_dl = new DirectionalLight(-1,-1,-1);
			_lp = new StaticLightPicker([_dl]);
			_scene.addChild(_dl);
			
			_awaystats = new AwayStats(_view, true, true);
		}
		
		private function demoStuff():void {
			_curtain = new Sprite();
			_curtain.mouseChildren = false;
			
			var _bmd:BitmapData = new BitmapData(_view.width, _view.height, false, 0x7F7F7F);
			_curtain.addChild(new Bitmap(_bmd));
			_curtain.alpha = .8;
			addChild(_curtain);
			
			var tf:TextField = new TextField();
			tf.x = 10;
			tf.y = 100;
			tf.width = 150;
			tf.text = "Mouse Over to activate.\n\nClick to change held object.";
			addChild(tf);
		}
		
	}
	
}