package arm;

import zui.Zui;
import zui.Zui.Theme;
import zui.Zui.Nodes;
import iron.App;
import iron.System;
import iron.Input;
import iron.Scene;
import iron.Data;
import iron.Time;
import iron.RenderPath;
import iron.ConstData;
import arm.ui.*;
import arm.io.ImportAsset;
import arm.shader.MakeMaterial;
import arm.Viewport;
import arm.Camera;
import arm.Res;
import arm.ProjectFormat;
#if (is_paint || is_sculpt)
import iron.Mat4;
import arm.data.*;
import arm.util.*;
import arm.render.RenderPathPaint;
#end

class Base {

	public static var uiEnabled = true;
	public static var isDragging = false;
	public static var isResizing = false;
	public static var dragAsset: TAsset = null;
	public static var dragSwatch: TSwatchColor = null;
	public static var dragFile: String = null;
	public static var dragFileIcon: Image = null;
	public static var dragTint = 0xffffffff;
	public static var dragSize = -1;
	public static var dragRect: TRect = null;
	public static var dragOffX = 0.0;
	public static var dragOffY = 0.0;
	public static var dragStart = 0.0;
	public static var dropX = 0.0;
	public static var dropY = 0.0;
	public static var font: Font = null;
	public static var theme: zui.Zui.Theme;
	public static var colorWheel: Image;
	public static var colorWheelGradient: Image;
	public static var uiBox: Zui;
	public static var uiMenu: Zui;
	public static var defaultElementW = 100;
	public static var defaultElementH = 28;
	public static var defaultFontSize = 13;
	public static var resHandle = new Handle();
	public static var bitsHandle = new Handle();
	static var dropPaths: Array<String> = [];
	static var appx = 0;
	static var appy = 0;
	static var lastWindowWidth = 0;
	static var lastWindowHeight = 0;
	#if (is_paint || is_sculpt)
	public static var dragMaterial: MaterialSlot = null;
	public static var dragLayer: LayerSlot = null;
	#end

	public static var pipeCopy: PipelineState;
	public static var pipeCopy8: PipelineState;
	public static var pipeCopy128: PipelineState;
	public static var pipeCopyBGRA: PipelineState;
	public static var pipeCopyRGB: PipelineState = null;
	#if (is_paint || is_sculpt)
	public static var pipeMerge: PipelineState = null;
	public static var pipeMergeR: PipelineState = null;
	public static var pipeMergeG: PipelineState = null;
	public static var pipeMergeB: PipelineState = null;
	public static var pipeMergeA: PipelineState = null;
	public static var pipeInvert8: PipelineState;
	public static var pipeApplyMask: PipelineState;
	public static var pipeMergeMask: PipelineState;
	public static var pipeColorIdToMask: PipelineState;
	public static var tex0: TextureUnit;
	public static var tex1: TextureUnit;
	public static var texmask: TextureUnit;
	public static var texa: TextureUnit;
	public static var opac: ConstantLocation;
	public static var blending: ConstantLocation;
	public static var tex0Mask: TextureUnit;
	public static var texaMask: TextureUnit;
	public static var tex0MergeMask: TextureUnit;
	public static var texaMergeMask: TextureUnit;
	public static var texColorId: TextureUnit;
	public static var texpaintColorId: TextureUnit;
	public static var opacMergeMask: ConstantLocation;
	public static var blendingMergeMask: ConstantLocation;
	public static var tempMaskImage: Image = null;
	#end
	#if is_lab
	public static var pipeCopyR: PipelineState;
	public static var pipeCopyG: PipelineState;
	public static var pipeCopyB: PipelineState;
	public static var pipeCopyA: PipelineState;
	public static var pipeCopyATex: TextureUnit;
	public static var pipeInpaintPreview: PipelineState;
	public static var tex0InpaintPreview: TextureUnit;
	public static var texaInpaintPreview: TextureUnit;
	#end
	public static var tempImage: Image = null;
	public static var expa: Image = null;
	public static var expb: Image = null;
	public static var expc: Image = null;
	public static var pipeCursor: PipelineState;
	public static var cursorVP: ConstantLocation;
	public static var cursorInvVP: ConstantLocation;
	public static var cursorMouse: ConstantLocation;
	public static var cursorTexStep: ConstantLocation;
	public static var cursorRadius: ConstantLocation;
	public static var cursorCameraRight: ConstantLocation;
	public static var cursorTint: ConstantLocation;
	public static var cursorTex: TextureUnit;
	public static var cursorGbufferD: TextureUnit;

	#if (is_paint || is_sculpt)
	public static inline var defaultBase = 0.5;
	public static inline var defaultRough = 0.4;
	#if (krom_android || krom_ios)
	public static inline var maxLayers = 18;
	#else
	public static inline var maxLayers = 255;
	#end
	#end
	public static inline var defaultFov = 0.69;

	public function new() {
		lastWindowWidth = System.width;
		lastWindowHeight = System.height;

		System.notifyOnDropFiles(function(dropPath: String) {
			#if krom_linux
			dropPath = untyped decodeURIComponent(dropPath);
			#end
			dropPath = dropPath.rtrim();
			dropPaths.push(dropPath);
		});

		System.notifyOnApplicationState(
			function() { // Foreground
				Context.raw.foregroundEvent = true;
				Context.raw.lastPaintX = -1;
				Context.raw.lastPaintY = -1;
			},
			function() {}, // Resume
			function() {}, // Pause
			function() { // Background
				// Release keys after alt-tab / win-tab
				Input.getKeyboard().upListener(KeyCode.Alt);
				Input.getKeyboard().upListener(KeyCode.Win);
			},
			function() { // Shutdown
				#if (krom_android || krom_ios)
				Project.projectSave();
				#end
			}
		);

		Krom.setSaveAndQuitCallback(saveAndQuitCallback);

		Data.getFont("font.ttf", function(f: Font) {
			Data.getImage("color_wheel.k", function(imageColorWheel: Image) {
				Data.getImage("color_wheel_gradient.k", function(imageColorWheelGradient: Image) {

					font = f;
					Config.loadTheme(Config.raw.theme, false);
					defaultElementW = theme.ELEMENT_W;
					defaultFontSize = theme.FONT_SIZE;
					Translator.loadTranslations(Config.raw.locale);
					UIFiles.filename = tr("untitled");
					#if (krom_android || krom_ios)
					System.title = tr("untitled");
					#end

					// Baked font for fast startup
					if (Config.raw.locale == "en") {
						font.font_ = Krom.g2_font_13(font.blob);
						font.fontGlyphs = Graphics2.fontGlyphs;
					}
					else font.init();

					colorWheel = imageColorWheel;
					colorWheelGradient = imageColorWheelGradient;
					Nodes.enumTexts = enumTexts;
					Nodes.tr = tr;
					uiBox = new Zui({ theme: Base.theme, font: f, scaleFactor: Config.raw.window_scale, color_wheel: colorWheel, black_white_gradient: colorWheelGradient });
					uiMenu = new Zui({ theme: Base.theme, font: f, scaleFactor: Config.raw.window_scale, color_wheel: colorWheel, black_white_gradient: colorWheelGradient });
					defaultElementH = uiMenu.t.ELEMENT_H;

					// Init plugins
					Plugin.init();
					if (Config.raw.plugins != null) {
						for (plugin in Config.raw.plugins) {
							Plugin.start(plugin);
						}
					}

					Args.parse();

					new Camera();
					new UIBase();
					new UINodes();
					new UIView2D();

					#if is_lab
					arm.logic.RandomNode.setSeed(Std.int(Time.time() * 4294967295));
					#end

					App.notifyOnUpdate(update);
					App.notifyOnRender2D(UIView2D.inst.render);
					App.notifyOnUpdate(UIView2D.inst.update);
					#if (is_paint || is_sculpt)
					App.notifyOnRender2D(UIBase.inst.renderCursor);
					#end
					App.notifyOnUpdate(UINodes.inst.update);
					App.notifyOnRender2D(UINodes.inst.render);
					App.notifyOnUpdate(UIBase.inst.update);
					App.notifyOnRender2D(UIBase.inst.render);
					App.notifyOnUpdate(Camera.inst.update);
					App.notifyOnRender2D(render);

					#if (is_paint || is_sculpt)
					appx = UIToolbar.inst.toolbarw;
					#end
					#if is_lab
					appx = 0;
					#end

					appy = UIHeader.headerh;
					if (Config.raw.layout[LayoutHeader] == 1) appy += UIHeader.headerh;
					var cam = Scene.active.camera;
					cam.data.raw.fov = Std.int(cam.data.raw.fov * 100) / 100;
					cam.buildProjection();

					Args.run();

					#if (krom_android || krom_ios)
					var hasProjects = Config.raw.recent_projects.length > 0;
					#else
					var hasProjects = true;
					#end

					if (Config.raw.splash_screen && hasProjects) {
						arm.ui.BoxProjects.show();
					}
				});
			});
		});
	}

	static function saveAndQuitCallback(save: Bool) {
		saveWindowRect();
		if (save) Project.projectSave(true);
		else System.stop();
	}

	#if (is_paint || is_sculpt)
	public static function w(): Int {
		// Drawing material preview
		if (UIBase.inst != null && Context.raw.materialPreview) {
			return RenderUtil.materialPreviewSize;
		}

		// Drawing decal preview
		if (UIBase.inst != null && Context.raw.decalPreview) {
			return RenderUtil.decalPreviewSize;
		}

		var res = 0;
		if (UINodes.inst == null || UIBase.inst == null) {
			var sidebarw = Config.raw.layout == null ? UIBase.defaultSidebarW : Config.raw.layout[LayoutSidebarW];
			res = System.width - sidebarw - UIToolbar.defaultToolbarW;
		}
		else if (UINodes.inst.show || UIView2D.inst.show) {
			res = System.width - Config.raw.layout[LayoutSidebarW] - Config.raw.layout[LayoutNodesW] - UIToolbar.inst.toolbarw;
		}
		else if (UIBase.inst.show) {
			res = System.width - Config.raw.layout[LayoutSidebarW] - UIToolbar.inst.toolbarw;
		}
		else { // Distract free
			res = System.width;
		}
		if (UIBase.inst != null && Context.raw.viewIndex > -1) {
			res = Std.int(res / 2);
		}
		if (Context.raw.paint2dView) {
			res = UIView2D.inst.ww;
		}

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}

	public static function h(): Int {
		// Drawing material preview
		if (UIBase.inst != null && Context.raw.materialPreview) {
			return RenderUtil.materialPreviewSize;
		}

		// Drawing decal preview
		if (UIBase.inst != null && Context.raw.decalPreview) {
			return RenderUtil.decalPreviewSize;
		}

		var res = System.height;

		if (UIBase.inst == null) {
			res -= UIHeader.defaultHeaderH * 2 + UIStatus.defaultStatusH;

			#if (krom_android || krom_ios)
			var layoutHeader = 0;
			#else
			var layoutHeader = 1;
			#end
			if (layoutHeader == 0) {
				res += UIHeader.headerh;
			}
		}
		else if (UIBase.inst != null && UIBase.inst.show && res > 0) {
			var statush = Config.raw.layout[LayoutStatusH];
			res -= Std.int(UIHeader.defaultHeaderH * 2 * Config.raw.window_scale) + statush;

			if (Config.raw.layout[LayoutHeader] == 0) {
				res += UIHeader.headerh;
			}
		}

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}
	#end

	#if is_lab
	public static function w(): Int {
		var res = 0;
		if (UINodes.inst == null) {
			res = System.width;
		}
		else if (UINodes.inst.show || UIView2D.inst.show) {
			res = System.width - Config.raw.layout[LayoutNodesW];
		}
		else { // Distract free
			res = System.width;
		}

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}

	public static function h(): Int {
		var res = System.height;
		if (UIBase.inst == null) {
			res -= UIHeader.defaultHeaderH * 2 + UIStatus.defaultStatusH;
		}
		else if (UIBase.inst != null && res > 0) {
			var statush = Config.raw.layout[LayoutStatusH];
			res -= Std.int(UIHeader.defaultHeaderH * 2 * Config.raw.window_scale) + statush;
		}

		return res > 0 ? res : 1; // App was minimized, force render path resize
	}
	#end

	public static function x(): Int {
		#if (is_paint || is_sculpt)
		return Context.raw.viewIndex == 1 ? appx + w() : appx;
		#end
		#if is_lab
		return appx;
		#end
	}

	public static function y(): Int {
		return appy;
	}

	public static function onResize() {
		if (System.width == 0 || System.height == 0) return;

		var ratioW = System.width / lastWindowWidth;
		lastWindowWidth = System.width;
		var ratioH = System.height / lastWindowHeight;
		lastWindowHeight = System.height;

		Config.raw.layout[LayoutNodesW] = Std.int(Config.raw.layout[LayoutNodesW] * ratioW);
		#if (is_paint || is_sculpt)
		Config.raw.layout[LayoutSidebarH0] = Std.int(Config.raw.layout[LayoutSidebarH0] * ratioH);
		Config.raw.layout[LayoutSidebarH1] = System.height - Config.raw.layout[LayoutSidebarH0];
		#end

		resize();

		#if (krom_linux || krom_darwin)
		saveWindowRect();
		#end
	}

	static function saveWindowRect() {
		#if (krom_windows || krom_linux || krom_darwin)
		Config.raw.window_w = System.width;
		Config.raw.window_h = System.height;
		Config.raw.window_x = System.x;
		Config.raw.window_y = System.y;
		Config.save();
		#end
	}

	public static function resize() {
		if (System.width == 0 || System.height == 0) return;

		var cam = Scene.active.camera;
		if (cam.data.raw.ortho != null) {
			cam.data.raw.ortho[2] = -2 * (App.h() / App.w());
			cam.data.raw.ortho[3] =  2 * (App.h() / App.w());
		}
		cam.buildProjection();

		if (Context.raw.cameraType == CameraOrthographic) {
			Viewport.updateCameraType(Context.raw.cameraType);
		}

		Context.raw.ddirty = 2;

		if (UIBase.inst.show) {
			#if (is_paint || is_sculpt)
			appx = UIToolbar.inst.toolbarw;
			#end
			#if is_lab
			appx = 0;
			#end
			appy = UIHeader.headerh * 2;
			if (Config.raw.layout[LayoutHeader] == 0) {
				appy -= UIHeader.headerh;
			}
		}
		else {
			appx = 0;
			appy = 0;
		}

		if (UINodes.inst.grid != null) {
			var _grid = UINodes.inst.grid;
			function _next() {
				_grid.unload();
			}
			Base.notifyOnNextFrame(_next);
			UINodes.inst.grid = null;
		}

		redrawUI();
	}

	public static function redrawUI() {
		UIHeader.inst.headerHandle.redraws = 2;
		UIBase.inst.hwnds[TabStatus].redraws = 2;
		UIMenubar.inst.menuHandle.redraws = 2;
		UIMenubar.inst.workspaceHandle.redraws = 2;
		UINodes.inst.hwnd.redraws = 2;
		UIBox.hwnd.redraws = 2;
		UIView2D.inst.hwnd.redraws = 2;
		if (Context.raw.ddirty < 0) Context.raw.ddirty = 0; // Redraw viewport
		#if (is_paint || is_sculpt)
		UIBase.inst.hwnds[TabSidebar0].redraws = 2;
		UIBase.inst.hwnds[TabSidebar1].redraws = 2;
		UIToolbar.inst.toolbarHandle.redraws = 2;
		if (Context.raw.splitView) Context.raw.ddirty = 1;
		#end
	}

	static function update() {
		var mouse = Input.getMouse();

		if (mouse.movementX != 0 || mouse.movementY != 0) {
			Krom.setMouseCursor(0); // Arrow
		}

		#if (is_paint || is_sculpt)
		var hasDrag = dragAsset != null || dragMaterial != null || dragLayer != null || dragFile != null || dragSwatch != null;
		#end
		#if is_lab
		var hasDrag = dragAsset != null || dragFile != null || dragSwatch != null;
		#end

		if (Config.raw.touch_ui) {
			// Touch and hold to activate dragging
			if (dragStart < 0.2) {
				if (hasDrag && mouse.down()) dragStart += Time.realDelta;
				else dragStart = 0;
				hasDrag = false;
			}
			if (mouse.released()) {
				dragStart = 0;
			}
			var moved = Math.abs(mouse.movementX) > 1 && Math.abs(mouse.movementY) > 1;
			if ((mouse.released() || moved) && !hasDrag) {
				dragAsset = null;
				dragSwatch = null;
				dragFile = null;
				dragFileIcon = null;
				isDragging = false;
				#if (is_paint || is_sculpt)
				dragMaterial = null;
				dragLayer = null;
				#end
			}
			// Disable touch scrolling while dragging is active
			Zui.touchScroll = !isDragging;
		}

		if (hasDrag && (mouse.movementX != 0 || mouse.movementY != 0)) {
			isDragging = true;
		}
		if (mouse.released() && hasDrag) {
			if (dragAsset != null) {
				if (Context.inNodes()) { // Create image texture
					UINodes.inst.acceptAssetDrag(Project.assets.indexOf(dragAsset));
				}
				else if (Context.inViewport()) {
					if (dragAsset.file.toLowerCase().endsWith(".hdr")) {
						var image = Project.getImage(dragAsset);
						arm.io.ImportEnvmap.run(dragAsset.file, image);
					}
				}
				#if (is_paint || is_sculpt)
				else if (Context.inLayers() || Context.in2dView()) { // Create mask
					Base.createImageMask(dragAsset);
				}
				#end
				dragAsset = null;
			}
			else if (dragSwatch != null) {
				if (Context.inNodes()) { // Create RGB node
					UINodes.inst.acceptSwatchDrag(dragSwatch);
				}
				else if (Context.inSwatches()) {
					TabSwatches.acceptSwatchDrag(dragSwatch);
				}
				#if (is_paint || is_sculpt)
				else if (Context.inMaterials()) {
					TabMaterials.acceptSwatchDrag(dragSwatch);
				}
				else if (Context.inViewport()) {
					var color = dragSwatch.base;
					color.A = dragSwatch.opacity;
					Base.createColorLayer(color.value, dragSwatch.occlusion, dragSwatch.roughness, dragSwatch.metallic);
				}
				else if (Context.inLayers() && TabLayers.canDropNewLayer(Context.raw.dragDestination)) {
					var color = dragSwatch.base;
					color.A = dragSwatch.opacity;
					Base.createColorLayer(color.value, dragSwatch.occlusion, dragSwatch.roughness, dragSwatch.metallic, Context.raw.dragDestination);
				}
				#end

				dragSwatch = null;
			}
			else if (dragFile != null) {
				if (!Context.inBrowser()) {
					dropX = mouse.x;
					dropY = mouse.y;

					#if (is_paint || is_sculpt)
					var materialCount = Project.materials.length;
					ImportAsset.run(dragFile, dropX, dropY, true, true, function() {
						// Asset was material
						if (Project.materials.length > materialCount) {
							dragMaterial = Context.raw.material;
							materialDropped();
						}
					});
					#end

					#if is_lab
					ImportAsset.run(dragFile, dropX, dropY);
					#end
				}
				dragFile = null;
				dragFileIcon = null;
			}
			#if (is_paint || is_sculpt)
			else if (dragMaterial != null) {
				materialDropped();
			}
			else if (dragLayer != null) {
				if (Context.inNodes()) {
					UINodes.inst.acceptLayerDrag(Project.layers.indexOf(dragLayer));
				}
				else if (Context.inLayers() && isDragging) {
					dragLayer.move(Context.raw.dragDestination);
					MakeMaterial.parseMeshMaterial();
				}
				dragLayer = null;
			}
			#end

			Krom.setMouseCursor(0); // Arrow
			isDragging = false;
		}
		if (Context.raw.colorPickerCallback != null && (mouse.released() || mouse.released("right"))) {
			Context.raw.colorPickerCallback = null;
			Context.selectTool(Context.raw.colorPickerPreviousTool);
		}

		handleDropPaths();

		#if (is_paint || is_sculpt)
		#if krom_windows
		var isPicker = Context.raw.tool == ToolPicker || Context.raw.tool == ToolMaterial;
		var decal = Context.raw.tool == ToolDecal || Context.raw.tool == ToolText;
		Zui.alwaysRedrawWindow = !Context.raw.cacheDraws ||
			UIMenu.show ||
			UIBox.show ||
			isDragging ||
			isPicker ||
			decal ||
			UIView2D.inst.show ||
			!Config.raw.brush_3d ||
			Context.raw.frame < 3;
		#end
		#end

		if (Zui.alwaysRedrawWindow && Context.raw.ddirty < 0) Context.raw.ddirty = 0;
	}

	#if (is_paint || is_sculpt)
	static function materialDropped() {
		// Material drag and dropped onto viewport or layers tab
		if (Context.inViewport()) {
			var uvType = Input.getKeyboard().down("control") ? UVProject : UVMap;
			var decalMat = uvType == UVProject ? RenderUtil.getDecalMat() : null;
			Base.createFillLayer(uvType, decalMat);
		}
		if (Context.inLayers() && TabLayers.canDropNewLayer(Context.raw.dragDestination)) {
			var uvType = Input.getKeyboard().down("control") ? UVProject : UVMap;
			var decalMat = uvType == UVProject ? RenderUtil.getDecalMat() : null;
			Base.createFillLayer(uvType, decalMat, Context.raw.dragDestination);
		}
		else if (Context.inNodes()) {
			UINodes.inst.acceptMaterialDrag(Project.materials.indexOf(dragMaterial));
		}
		dragMaterial = null;
	}
	#end

	static function handleDropPaths() {
		if (dropPaths.length > 0) {
			var mouse = Input.getMouse();
			#if (krom_linux || krom_darwin)
			var wait = !mouse.moved; // Mouse coords not updated during drag
			#else
			var wait = false;
			#end
			if (!wait) {
				dropX = mouse.x;
				dropY = mouse.y;
				var dropPath = dropPaths.shift();
				ImportAsset.run(dropPath, dropX, dropY);
			}
		}
	}

	#if (is_paint || is_sculpt)
	static function getDragBackground(): TRect {
		var icons = Res.get("icons.k");
		if (dragLayer != null && !dragLayer.isGroup() && dragLayer.fill_layer == null) {
			return Res.tile50(icons, 4, 1);
		}
		return null;
	}
	#end

	static function getDragImage(): Image {
		dragTint = 0xffffffff;
		dragSize = -1;
		dragRect = null;
		if (dragAsset != null) {
			return Project.getImage(dragAsset);
		}
		if (dragSwatch != null) {
			dragTint = dragSwatch.base;
			dragSize = 26;
			return TabSwatches.empty;
		}
		if (dragFile != null) {
			if (dragFileIcon != null) return dragFileIcon;
			var icons = Res.get("icons.k");
			dragRect = dragFile.indexOf(".") > 0 ? Res.tile50(icons, 3, 1) : Res.tile50(icons, 2, 1);
			dragTint = UIBase.inst.ui.t.HIGHLIGHT_COL;
			return icons;
		}

		#if is_paint
		if (dragMaterial != null) {
			return dragMaterial.imageIcon;
		}
		if (dragLayer != null && dragLayer.isGroup()) {
			var icons = Res.get("icons.k");
			var folderClosed = Res.tile50(icons, 2, 1);
			var folderOpen = Res.tile50(icons, 8, 1);
			dragRect = dragLayer.show_panel ? folderOpen : folderClosed;
			dragTint = UIBase.inst.ui.t.LABEL_COL - 0x00202020;
			return icons;
		}
		if (dragLayer != null && dragLayer.isMask() && dragLayer.fill_layer == null) {
			TabLayers.makeMaskPreviewRgba32(dragLayer);
			return Context.raw.maskPreviewRgba32;
		}
		if (dragLayer != null) {
			return dragLayer.fill_layer != null ? dragLayer.fill_layer.imageIcon : dragLayer.texpaint_preview;
		}
		#end

		return null;
	}

	static function render(g: Graphics2) {
		if (System.width == 0 || System.height == 0) return;

		if (Context.raw.frame == 2) {
			#if (is_paint || is_sculpt)
			RenderUtil.makeMaterialPreview();
			UIBase.inst.hwnds[TabSidebar1].redraws = 2;
			#end

			MakeMaterial.parseMeshMaterial();
			MakeMaterial.parsePaintMaterial();
			Context.raw.ddirty = 0;

			#if (is_paint || is_sculpt)
			if (History.undoLayers == null) {
				History.undoLayers = [];
				for (i in 0...Config.raw.undo_steps) {
					var l = new LayerSlot("_undo" + History.undoLayers.length);
					History.undoLayers.push(l);
				}
			}
			#end

			// Default workspace
			if (Config.raw.workspace != 0) {
				UIHeader.inst.worktab.position = Config.raw.workspace;
				UIMenubar.inst.workspaceHandle.redraws = 2;
				UIHeader.inst.worktab.changed = true;
			}

			// Default camera controls
			Context.raw.cameraControls = Config.raw.camera_controls;

			#if is_lab
			Base.notifyOnNextFrame(function() {
				Base.notifyOnNextFrame(function() {
					TabMeshes.setDefaultMesh(".Sphere");
				});
			});
			#end

			#if is_sculpt
			Base.notifyOnNextFrame(function() {
				Base.notifyOnNextFrame(function() {
					Context.raw.projectType = ModelSphere;
					Project.projectNew();
				});
			});
			#end
		}
		else if (Context.raw.frame == 3) {
			Context.raw.ddirty = 3;
		}
		Context.raw.frame++;

		var mouse = Input.getMouse();
		if (isDragging) {
			Krom.setMouseCursor(1); // Hand
			var img = getDragImage();

			#if (is_paint || is_sculpt)
			var scaleFactor = UIBase.inst.ui.SCALE();
			#end
			#if is_lab
			var scaleFactor = uiBox.SCALE();
			#end

			var size = (dragSize == -1 ? 50 : dragSize) * scaleFactor;
			var ratio = size / img.width;
			var h = img.height * ratio;

			#if (is_lab || krom_direct3d11 || krom_direct3d12 || krom_metal || krom_vulkan)
			var inv = 0;
			#else
			var inv = (dragMaterial != null || (dragLayer != null && dragLayer.fill_layer != null)) ? h : 0;
			#end

			g.color = dragTint;

			#if (is_paint || is_sculpt)
			var bgRect = getDragBackground();
			if (bgRect != null) {
				g.drawScaledSubImage(Res.get("icons.k"), bgRect.x, bgRect.y, bgRect.w, bgRect.h, mouse.x + dragOffX, mouse.y + dragOffY + inv, size, h - inv * 2);
			}
			#end

			dragRect == null ?
				g.drawScaledImage(img, mouse.x + dragOffX, mouse.y + dragOffY + inv, size, h - inv * 2) :
				g.drawScaledSubImage(img, dragRect.x, dragRect.y, dragRect.w, dragRect.h, mouse.x + dragOffX, mouse.y + dragOffY + inv, size, h - inv * 2);
			g.color = 0xffffffff;
		}

		var usingMenu = UIMenu.show && mouse.y > UIHeader.headerh;
		uiEnabled = !UIBox.show && !usingMenu && !isComboSelected();
		if (UIBox.show) UIBox.render(g);
		if (UIMenu.show) UIMenu.render(g);

		// Save last pos for continuos paint
		Context.raw.lastPaintVecX = Context.raw.paintVec.x;
		Context.raw.lastPaintVecY = Context.raw.paintVec.y;

		#if (krom_android || krom_ios)
		// No mouse move events for touch, re-init last paint position on touch start
		if (!mouse.down()) {
			Context.raw.lastPaintX = -1;
			Context.raw.lastPaintY = -1;
		}
		#end
	}

	public static function enumTexts(nodeType: String): Array<String> {
		#if (is_paint || is_sculpt)
		if (nodeType == "TEX_IMAGE") {
			return Project.assetNames.length > 0 ? Project.assetNames : [""];
		}
		if (nodeType == "LAYER" || nodeType == "LAYER_MASK") {
			var layerNames: Array<String> = [];
			for (l in Project.layers) layerNames.push(l.name);
			return layerNames;
		}
		if (nodeType == "MATERIAL") {
			var materialNames: Array<String> = [];
			for (m in Project.materials) materialNames.push(m.canvas.name);
			return materialNames;
		}
		#end

		#if is_lab
		if (nodeType == "ImageTextureNode") {
			return Project.assetNames.length > 0 ? Project.assetNames : [""];
		}
		#end

		return null;
	}

	public static function getAssetIndex(fileName: String): Int {
		var i = Project.assetNames.indexOf(fileName);
		return i >= 0 ? i : 0;
	}

	public static function notifyOnNextFrame(f: Void->Void) {
		function _render(_) {
			App.notifyOnInit(function() {
				function _update() {
					App.notifyOnInit(f);
					App.removeUpdate(_update);
				}
				App.notifyOnUpdate(_update);
			});
			App.removeRender(_render);
		}
		App.notifyOnRender(_render);
	}

	public static function toggleFullscreen() {
		if (System.mode == WindowMode.Windowed) {
			#if (krom_windows || krom_linux || krom_darwin)
			Config.raw.window_w = System.width;
			Config.raw.window_h = System.height;
			Config.raw.window_x = System.x;
			Config.raw.window_y = System.y;
			#end
			System.mode = WindowMode.Fullscreen;
		}
		else {
			System.mode = WindowMode.Windowed;
			System.resize(Config.raw.window_w, Config.raw.window_h);
			System.move(Config.raw.window_x, Config.raw.window_y);
		}
	}

	public static function isScrolling(): Bool {
		for (ui in getUIs()) if (ui.isScrolling) return true;
		return false;
	}

	public static function isComboSelected(): Bool {
		for (ui in getUIs()) if (ui.comboSelectedHandle_ptr != null) return true;
		return false;
	}

	public static function getUIs(): Array<Zui> {
		return [Base.uiBox, Base.uiMenu, UIBase.inst.ui, UINodes.inst.ui, UIView2D.inst.ui];
	}

	public static function isDecalLayer(): Bool {
		#if is_paint
		var isPaint = Context.raw.tool != ToolMaterial && Context.raw.tool != ToolBake;
		return isPaint && Context.raw.layer.fill_layer != null && Context.raw.layer.uvType == UVProject;
		#end

		#if (is_sculpt || is_lab)
		return false;
		#end
	}

	public static function redrawStatus() {
		if (arm.ui.UIStatus.inst != null) {
			UIBase.inst.hwnds[TabStatus].redraws = 2;
		}
	}

	public static function redrawConsole() {
		var statush = Config.raw.layout[LayoutStatusH];
		if (arm.ui.UIStatus.inst != null && arm.ui.UIBase.inst != null && arm.ui.UIBase.inst.ui != null && statush > arm.ui.UIStatus.defaultStatusH * arm.ui.UIBase.inst.ui.SCALE()) {
			UIBase.inst.hwnds[TabStatus].redraws = 2;
		}
	}

	public static function initLayout() {
		var show2d = (UINodes.inst != null && UINodes.inst.show) || (UIView2D.inst != null && UIView2D.inst.show);

		var raw = Config.raw;
		raw.layout = [
			#if (is_paint || is_sculpt)
			Std.int(UIBase.defaultSidebarW * raw.window_scale), // LayoutSidebarW
			Std.int(System.height / 2), // LayoutSidebarH0
			Std.int(System.height / 2), // LayoutSidebarH1
			#end

			#if krom_ios
			show2d ? Std.int((App.w() + raw.layout[LayoutNodesW]) * 0.473) : Std.int(App.w() * 0.473), // LayoutNodesW
			#elseif krom_android
			show2d ? Std.int((App.w() + raw.layout[LayoutNodesW]) * 0.473) : Std.int(App.w() * 0.473),
			#else
			show2d ? Std.int((App.w() + raw.layout[LayoutNodesW]) * 0.515) : Std.int(App.w() * 0.515), // Align with ui header controls
			#end

			Std.int(App.h() / 2), // LayoutNodesH
			Std.int(UIStatus.defaultStatusH * raw.window_scale), // LayoutStatusH

			#if (krom_android || krom_ios)
			0, // LayoutHeader
			#else
			1,
			#end
		];

		raw.layout_tabs = [
			#if (is_paint || is_sculpt)
			0,
			0,
			#end
			0
		];
	}

	public static function initConfig() {
		var raw = Config.raw;
		raw.recent_projects = [];
		raw.bookmarks = [];
		raw.plugins = [];
		#if (krom_android || krom_ios)
		raw.keymap = "touch.json";
		#else
		raw.keymap = "default.json";
		#end
		raw.theme = "default.json";
		raw.server = "https://armorpaint.fra1.digitaloceanspaces.com";
		raw.undo_steps = 4;
		raw.pressure_radius = true;
		raw.pressure_sensitivity = 1.0;
		raw.camera_zoom_speed = 1.0;
		raw.camera_pan_speed = 1.0;
		raw.camera_rotation_speed = 1.0;
		raw.zoom_direction = ZoomVertical;
		#if (is_paint || is_sculpt)
		raw.displace_strength = 0.0;
		#else
		raw.displace_strength = 1.0;
		#end
		raw.wrap_mouse = false;
		#if is_paint
		raw.workspace = Space3D;
		#end
		#if is_sculpt
		raw.workspace = Space3D;
		#end
		#if is_lab
		raw.workspace = Space2D;
		#end
		#if (krom_android || krom_ios)
		raw.camera_controls = ControlsRotate;
		#else
		raw.camera_controls = ControlsOrbit;
		#end
		raw.layer_res = Res2048;
		#if (krom_android || krom_ios)
		raw.touch_ui = true;
		raw.splash_screen = true;
		#else
		raw.touch_ui = false;
		raw.splash_screen = false;
		#end
		#if (is_paint || is_sculpt)
		raw.node_preview = true;
		#else
		raw.node_preview = false;
		#end

		#if (is_paint || is_sculpt)
		raw.pressure_hardness = true;
		raw.pressure_angle = false;
		raw.pressure_opacity = false;
		#if (krom_vulkan || krom_ios)
		raw.material_live = false;
		#else
		raw.material_live = true;
		#end
		raw.brush_3d = true;
		raw.brush_depth_reject = true;
		raw.brush_angle_reject = true;
		raw.brush_live = false;
		raw.show_asset_names = false;
		#end

		#if is_paint
		raw.dilate = DilateInstant;
		raw.dilate_radius = 2;
		#end

		#if is_lab
		raw.gpu_inference = true;
		#end
	}

	public static function initLayers() {
		#if (is_paint || is_sculpt)
		Project.layers[0].clear(Color.fromFloats(defaultBase, defaultBase, defaultBase, 1.0));
		#end

		#if is_lab
		var texpaint = RenderPath.active.renderTargets.get("texpaint").image;
		var texpaint_nor = RenderPath.active.renderTargets.get("texpaint_nor").image;
		var texpaint_pack = RenderPath.active.renderTargets.get("texpaint_pack").image;
		texpaint.g2.begin(false);
		texpaint.g2.drawScaledImage(Res.get("placeholder.k"), 0, 0, Config.getTextureResX(), Config.getTextureResY()); // Base
		texpaint.g2.end();
		texpaint_nor.g4.begin();
		texpaint_nor.g4.clear(Color.fromFloats(0.5, 0.5, 1.0, 0.0)); // Nor
		texpaint_nor.g4.end();
		texpaint_pack.g4.begin();
		texpaint_pack.g4.clear(Color.fromFloats(1.0, 0.4, 0.0, 0.0)); // Occ, rough, met
		texpaint_pack.g4.end();
		var texpaint_nor_empty = RenderPath.active.renderTargets.get("texpaint_nor_empty").image;
		var texpaint_pack_empty = RenderPath.active.renderTargets.get("texpaint_pack_empty").image;
		texpaint_nor_empty.g4.begin();
		texpaint_nor_empty.g4.clear(Color.fromFloats(0.5, 0.5, 1.0, 0.0)); // Nor
		texpaint_nor_empty.g4.end();
		texpaint_pack_empty.g4.begin();
		texpaint_pack_empty.g4.clear(Color.fromFloats(1.0, 0.4, 0.0, 0.0)); // Occ, rough, met
		texpaint_pack_empty.g4.end();
		#end
	}

	#if (is_paint || is_sculpt)
	public static function resizeLayers() {
		var C = Config.raw;
		if (Base.resHandle.position >= Std.int(Res16384)) { // Save memory for >=16k
			C.undo_steps = 1;
			if (Context.raw.undoHandle != null) {
				Context.raw.undoHandle.value = C.undo_steps;
			}
			while (History.undoLayers.length > C.undo_steps) {
				var l = History.undoLayers.pop();
				Base.notifyOnNextFrame(function() {
					l.unload();
				});
			}
		}
		for (l in Project.layers) l.resizeAndSetBits();
		for (l in History.undoLayers) l.resizeAndSetBits();
		var rts = RenderPath.active.renderTargets;
		var _texpaint_blend0 = rts.get("texpaint_blend0").image;
		Base.notifyOnNextFrame(function() {
			_texpaint_blend0.unload();
		});
		rts.get("texpaint_blend0").raw.width = Config.getTextureResX();
		rts.get("texpaint_blend0").raw.height = Config.getTextureResY();
		rts.get("texpaint_blend0").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);
		var _texpaint_blend1 = rts.get("texpaint_blend1").image;
		Base.notifyOnNextFrame(function() {
			_texpaint_blend1.unload();
		});
		rts.get("texpaint_blend1").raw.width = Config.getTextureResX();
		rts.get("texpaint_blend1").raw.height = Config.getTextureResY();
		rts.get("texpaint_blend1").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);
		Context.raw.brushBlendDirty = true;
		if (rts.get("texpaint_blur") != null) {
			var _texpaint_blur = rts.get("texpaint_blur").image;
			Base.notifyOnNextFrame(function() {
				_texpaint_blur.unload();
			});
			var sizeX = Std.int(Config.getTextureResX() * 0.95);
			var sizeY = Std.int(Config.getTextureResY() * 0.95);
			rts.get("texpaint_blur").raw.width = sizeX;
			rts.get("texpaint_blur").raw.height = sizeY;
			rts.get("texpaint_blur").image = Image.createRenderTarget(sizeX, sizeY);
		}
		if (RenderPathPaint.liveLayer != null) RenderPathPaint.liveLayer.resizeAndSetBits();
		#if (krom_direct3d12 || krom_vulkan || krom_metal)
		arm.render.RenderPathRaytrace.ready = false; // Rebuild baketex
		#end
		Context.raw.ddirty = 2;
	}

	public static function setLayerBits() {
		for (l in Project.layers) l.resizeAndSetBits();
		for (l in History.undoLayers) l.resizeAndSetBits();
	}

	static function makeMergePipe(red: Bool, green: Bool, blue: Bool, alpha: Bool): PipelineState {
		var pipe = new PipelineState();
		pipe.vertexShader = System.getShader("pass.vert");
		pipe.fragmentShader = System.getShader("layer_merge.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipe.inputLayout = [vs];
		pipe.colorWriteMasksRed = [red];
		pipe.colorWriteMasksGreen = [green];
		pipe.colorWriteMasksBlue = [blue];
		pipe.colorWriteMasksAlpha = [alpha];
		pipe.compile();
		return pipe;
	}
	#end

	public static function makePipe() {
		#if (is_paint || is_sculpt)
		pipeMerge = makeMergePipe(true, true, true, true);
		pipeMergeR = makeMergePipe(true, false, false, false);
		pipeMergeG = makeMergePipe(false, true, false, false);
		pipeMergeB = makeMergePipe(false, false, true, false);
		pipeMergeA = makeMergePipe(false, false, false, true);
		tex0 = pipeMerge.getTextureUnit("tex0"); // Always binding texpaint.a for blending
		tex1 = pipeMerge.getTextureUnit("tex1");
		texmask = pipeMerge.getTextureUnit("texmask");
		texa = pipeMerge.getTextureUnit("texa");
		opac = pipeMerge.getConstantLocation("opac");
		blending = pipeMerge.getConstantLocation("blending");
		#end

		pipeCopy = new PipelineState();
		pipeCopy.vertexShader = System.getShader("layer_view.vert");
		pipeCopy.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopy.inputLayout = [vs];
		pipeCopy.compile();

		pipeCopyBGRA = new PipelineState();
		pipeCopyBGRA.vertexShader = System.getShader("layer_view.vert");
		pipeCopyBGRA.fragmentShader = System.getShader("layer_copy_bgra.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopyBGRA.inputLayout = [vs];
		pipeCopyBGRA.compile();

		#if (krom_metal || krom_vulkan || krom_direct3d12)
		pipeCopy8 = new PipelineState();
		pipeCopy8.vertexShader = System.getShader("layer_view.vert");
		pipeCopy8.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopy8.inputLayout = [vs];
		pipeCopy8.colorAttachmentCount = 1;
		pipeCopy8.colorAttachments[0] = TextureFormat.R8;
		pipeCopy8.compile();

		pipeCopy128 = new PipelineState();
		pipeCopy128.vertexShader = System.getShader("layer_view.vert");
		pipeCopy128.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopy128.inputLayout = [vs];
		pipeCopy128.colorAttachmentCount = 1;
		pipeCopy128.colorAttachments[0] = TextureFormat.RGBA128;
		pipeCopy128.compile();
		#else
		pipeCopy8 = pipeCopy;
		pipeCopy128 = pipeCopy;
		#end

		#if (is_paint || is_sculpt)
		pipeInvert8 = new PipelineState();
		pipeInvert8.vertexShader = System.getShader("layer_view.vert");
		pipeInvert8.fragmentShader = System.getShader("layer_invert.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeInvert8.inputLayout = [vs];
		pipeInvert8.colorAttachmentCount = 1;
		pipeInvert8.colorAttachments[0] = TextureFormat.R8;
		pipeInvert8.compile();

		pipeApplyMask = new PipelineState();
		pipeApplyMask.vertexShader = System.getShader("pass.vert");
		pipeApplyMask.fragmentShader = System.getShader("mask_apply.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipeApplyMask.inputLayout = [vs];
		pipeApplyMask.compile();
		tex0Mask = pipeApplyMask.getTextureUnit("tex0");
		texaMask = pipeApplyMask.getTextureUnit("texa");

		pipeMergeMask = new PipelineState();
		pipeMergeMask.vertexShader = System.getShader("pass.vert");
		pipeMergeMask.fragmentShader = System.getShader("mask_merge.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipeMergeMask.inputLayout = [vs];
		pipeMergeMask.compile();
		tex0MergeMask = pipeMergeMask.getTextureUnit("tex0");
		texaMergeMask = pipeMergeMask.getTextureUnit("texa");
		opacMergeMask = pipeMergeMask.getConstantLocation("opac");
		blendingMergeMask = pipeMergeMask.getConstantLocation("blending");

		pipeColorIdToMask = new PipelineState();
		pipeColorIdToMask.vertexShader = System.getShader("pass.vert");
		pipeColorIdToMask.fragmentShader = System.getShader("mask_colorid.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipeColorIdToMask.inputLayout = [vs];
		pipeColorIdToMask.compile();
		texpaintColorId = pipeColorIdToMask.getTextureUnit("texpaint_colorid");
		texColorId = pipeColorIdToMask.getTextureUnit("texcolorid");
		#end

		#if is_lab
		pipeCopyR = new PipelineState();
		pipeCopyR.vertexShader = System.getShader("layer_view.vert");
		pipeCopyR.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopyR.inputLayout = [vs];
		pipeCopyR.colorWriteMasksGreen = [false];
		pipeCopyR.colorWriteMasksBlue = [false];
		pipeCopyR.colorWriteMasksAlpha = [false];
		pipeCopyR.compile();

		pipeCopyG = new PipelineState();
		pipeCopyG.vertexShader = System.getShader("layer_view.vert");
		pipeCopyG.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopyG.inputLayout = [vs];
		pipeCopyG.colorWriteMasksRed = [false];
		pipeCopyG.colorWriteMasksBlue = [false];
		pipeCopyG.colorWriteMasksAlpha = [false];
		pipeCopyG.compile();

		pipeCopyB = new PipelineState();
		pipeCopyB.vertexShader = System.getShader("layer_view.vert");
		pipeCopyB.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopyB.inputLayout = [vs];
		pipeCopyB.colorWriteMasksRed = [false];
		pipeCopyB.colorWriteMasksGreen = [false];
		pipeCopyB.colorWriteMasksAlpha = [false];
		pipeCopyB.compile();

		pipeInpaintPreview = new PipelineState();
		pipeInpaintPreview.vertexShader = System.getShader("pass.vert");
		pipeInpaintPreview.fragmentShader = System.getShader("inpaint_preview.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipeInpaintPreview.inputLayout = [vs];
		pipeInpaintPreview.compile();
		tex0InpaintPreview = pipeInpaintPreview.getTextureUnit("tex0");
		texaInpaintPreview = pipeInpaintPreview.getTextureUnit("texa");
		#end
	}

	public static function makePipeCopyRGB() {
		pipeCopyRGB = new PipelineState();
		pipeCopyRGB.vertexShader = System.getShader("layer_view.vert");
		pipeCopyRGB.fragmentShader = System.getShader("layer_copy.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_3X);
		vs.add("tex", VertexData.F32_2X);
		vs.add("col", VertexData.U8_4X_Normalized);
		pipeCopyRGB.inputLayout = [vs];
		pipeCopyRGB.colorWriteMasksAlpha = [false];
		pipeCopyRGB.compile();
	}

	#if is_lab
	public static function makePipeCopyA() {
		pipeCopyA = new PipelineState();
		pipeCopyA.vertexShader = System.getShader("pass.vert");
		pipeCopyA.fragmentShader = System.getShader("layer_copy_rrrr.frag");
		var vs = new VertexStructure();
		vs.add("pos", VertexData.F32_2X);
		pipeCopyA.inputLayout = [vs];
		pipeCopyA.colorWriteMasksRed = [false];
		pipeCopyA.colorWriteMasksGreen = [false];
		pipeCopyA.colorWriteMasksBlue = [false];
		pipeCopyA.compile();
		pipeCopyATex = pipeCopyA.getTextureUnit("tex");
	}
	#end

	public static function makeCursorPipe() {
		pipeCursor = new PipelineState();
		pipeCursor.vertexShader = System.getShader("cursor.vert");
		pipeCursor.fragmentShader = System.getShader("cursor.frag");
		var vs = new VertexStructure();
		#if (krom_metal || krom_vulkan)
		vs.add("tex", VertexData.I16_2X_Normalized);
		#else
		vs.add("pos", VertexData.I16_4X_Normalized);
		vs.add("nor", VertexData.I16_2X_Normalized);
		vs.add("tex", VertexData.I16_2X_Normalized);
		#end
		pipeCursor.inputLayout = [vs];
		pipeCursor.blendSource = BlendingFactor.SourceAlpha;
		pipeCursor.blendDestination = BlendingFactor.InverseSourceAlpha;
		pipeCursor.depthWrite = false;
		pipeCursor.depthMode = CompareMode.Always;
		pipeCursor.compile();
		cursorVP = pipeCursor.getConstantLocation("VP");
		cursorInvVP = pipeCursor.getConstantLocation("invVP");
		cursorMouse = pipeCursor.getConstantLocation("mouse");
		cursorTexStep = pipeCursor.getConstantLocation("texStep");
		cursorRadius = pipeCursor.getConstantLocation("radius");
		cursorCameraRight = pipeCursor.getConstantLocation("cameraRight");
		cursorTint = pipeCursor.getConstantLocation("tint");
		cursorGbufferD = pipeCursor.getTextureUnit("gbufferD");
		cursorTex = pipeCursor.getTextureUnit("tex");
	}

	public static function makeTempImg() {
		#if (is_paint || is_sculpt)
		var l = Project.layers[0];
		#end
		#if is_lab
		var l = arm.logic.BrushOutputNode.inst;
		#end

		if (tempImage != null && (tempImage.width != l.texpaint.width || tempImage.height != l.texpaint.height || tempImage.format != l.texpaint.format)) {
			var _temptex0 = RenderPath.active.renderTargets.get("temptex0");
			Base.notifyOnNextFrame(function() {
				_temptex0.unload();
			});
			RenderPath.active.renderTargets.remove("temptex0");
			tempImage = null;
		}
		if (tempImage == null) {
			#if (is_paint || is_sculpt)
			var format = Base.bitsHandle.position == Bits8  ? "RGBA32" :
					 	 Base.bitsHandle.position == Bits16 ? "RGBA64" :
					 										  "RGBA128";
			#end
			#if is_lab
			var format = "RGBA32";
			#end

			var t = new RenderTargetRaw();
			t.name = "temptex0";
			t.width = l.texpaint.width;
			t.height = l.texpaint.height;
			t.format = format;
			var rt = RenderPath.active.createRenderTarget(t);
			tempImage = rt.image;
		}
	}

	#if (is_paint || is_sculpt)
	public static function makeTempMaskImg() {
		if (tempMaskImage != null && (tempMaskImage.width != Config.getTextureResX() || tempMaskImage.height != Config.getTextureResY())) {
			var _tempMaskImage = tempMaskImage;
			Base.notifyOnNextFrame(function() {
				_tempMaskImage.unload();
			});
			tempMaskImage = null;
		}
		if (tempMaskImage == null) {
			tempMaskImage = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);
		}
	}
	#end

	public static function makeExportImg() {
		#if (is_paint || is_sculpt)
		var l = Project.layers[0];
		#end
		#if is_lab
		var l = arm.logic.BrushOutputNode.inst;
		#end

		if (expa != null && (expa.width != l.texpaint.width || expa.height != l.texpaint.height || expa.format != l.texpaint.format)) {
			var _expa = expa;
			var _expb = expb;
			var _expc = expc;
			Base.notifyOnNextFrame(function() {
				_expa.unload();
				_expb.unload();
				_expc.unload();
			});
			expa = null;
			expb = null;
			expc = null;
			RenderPath.active.renderTargets.remove("expa");
			RenderPath.active.renderTargets.remove("expb");
			RenderPath.active.renderTargets.remove("expc");
		}
		if (expa == null) {
			#if (is_paint || is_sculpt)
			var format = Base.bitsHandle.position == Bits8  ? "RGBA32" :
					 	 Base.bitsHandle.position == Bits16 ? "RGBA64" :
					 										  "RGBA128";
			#end
			#if is_lab
			var format = "RGBA32";
			#end

			var t = new RenderTargetRaw();
			t.name = "expa";
			t.width = l.texpaint.width;
			t.height = l.texpaint.height;
			t.format = format;
			var rt = RenderPath.active.createRenderTarget(t);
			expa = rt.image;

			var t = new RenderTargetRaw();
			t.name = "expb";
			t.width = l.texpaint.width;
			t.height = l.texpaint.height;
			t.format = format;
			var rt = RenderPath.active.createRenderTarget(t);
			expb = rt.image;

			var t = new RenderTargetRaw();
			t.name = "expc";
			t.width = l.texpaint.width;
			t.height = l.texpaint.height;
			t.format = format;
			var rt = RenderPath.active.createRenderTarget(t);
			expc = rt.image;
		}
	}

	#if (is_paint || is_sculpt)
	public static function duplicateLayer(l: LayerSlot) {
		if (!l.isGroup()) {
			var newLayer = l.duplicate();
			Context.setLayer(newLayer);
			var masks = l.getMasks(false);
			if (masks != null) {
				for (m in masks) {
					m = m.duplicate();
					m.parent = newLayer;
					Project.layers.remove(m);
					Project.layers.insert(Project.layers.indexOf(newLayer), m);
				}
			}
			Context.setLayer(newLayer);
		}
		else {
			var newGroup = Base.newGroup();
			Project.layers.remove(newGroup);
			Project.layers.insert(Project.layers.indexOf(l) + 1, newGroup);
			// group.show_panel = true;
			for (c in l.getChildren()) {
				var masks = c.getMasks(false);
				var newLayer = c.duplicate();
				newLayer.parent = newGroup;
				Project.layers.remove(newLayer);
				Project.layers.insert(Project.layers.indexOf(newGroup), newLayer);
				if (masks != null) {
					for (m in masks) {
						var newMask = m.duplicate();
						newMask.parent = newLayer;
						Project.layers.remove(newMask);
						Project.layers.insert(Project.layers.indexOf(newLayer), newMask);
					}
				}
			}
			var groupMasks = l.getMasks();
			if (groupMasks != null) {
				for (m in groupMasks) {
					var newMask = m.duplicate();
					newMask.parent = newGroup;
					Project.layers.remove(newMask);
					Project.layers.insert(Project.layers.indexOf(newGroup), newMask);
				}
			}
			Context.setLayer(newGroup);
		}
	}

	public static function applyMasks(l: LayerSlot) {
		var masks = l.getMasks();

		if (masks != null) {
			for (i in 0...masks.length - 1) {
				mergeLayer(masks[i + 1], masks[i]);
				masks[i].delete();
			}
			masks[masks.length - 1].applyMask();
			Context.raw.layerPreviewDirty = true;
		}
	}

	public static function mergeDown() {
		var l1 = Context.raw.layer;

		if (l1.isGroup()) {
			l1 = mergeGroup(l1);
		}
		else if (l1.hasMasks()) { // It is a layer
			applyMasks(l1);
			Context.setLayer(l1);
		}

		var l0 = Project.layers[Project.layers.indexOf(l1) - 1];

		if (l0.isGroup()) {
			l0 = mergeGroup(l0);
		}
		else if (l0.hasMasks()) { // It is a layer
			applyMasks(l0);
			Context.setLayer(l0);
		}

		mergeLayer(l0, l1);
		l1.delete();
		Context.setLayer(l0);
		Context.raw.layerPreviewDirty = true;
	}

	public static function mergeGroup(l: LayerSlot) {
		if (!l.isGroup()) return null;

		var children = l.getChildren();

		if (children.length == 1 && children[0].hasMasks(false)) {
			Base.applyMasks(children[0]);
		}

		for (i in 0...children.length - 1) {
			Context.setLayer(children[children.length - 1 - i]);
			History.mergeLayers();
			Base.mergeDown();
		}

		// Now apply the group masks
		var masks = l.getMasks();
		if (masks != null) {
			for (i in 0...masks.length - 1) {
				mergeLayer(masks[i + 1], masks[i]);
				masks[i].delete();
			}
			Base.applyMask(children[0], masks[masks.length - 1]);
		}

		children[0].parent = null;
		children[0].name = l.name;
		if (children[0].fill_layer != null) children[0].toPaintLayer();
		l.delete();
		return children[0];
	}

	public static function mergeLayer(l0 : LayerSlot, l1: LayerSlot, use_mask = false) {
		if (!l1.visible || l1.isGroup()) return;

		if (pipeMerge == null) makePipe();
		makeTempImg();
		if (ConstData.screenAlignedVB == null) ConstData.createScreenAlignedData();

		tempImage.g2.begin(false); // Copy to temp
		tempImage.g2.pipeline = pipeCopy;
		tempImage.g2.drawImage(l0.texpaint, 0, 0);
		tempImage.g2.pipeline = null;
		tempImage.g2.end();

		var empty = RenderPath.active.renderTargets.get("empty_white").image;
		var mask = empty;
		var l1masks =  use_mask ? l1.getMasks() : null;
		if (l1masks != null) {
			// for (i in 1...l1masks.length - 1) {
			// 	mergeLayer(l1masks[i + 1], l1masks[i]);
			// }
			mask = l1masks[0].texpaint;
		}

		if (l1.isMask()) {
			l0.texpaint.g4.begin();
			l0.texpaint.g4.setPipeline(pipeMergeMask);
			l0.texpaint.g4.setTexture(Base.tex0MergeMask, l1.texpaint);
			l0.texpaint.g4.setTexture(Base.texaMergeMask, tempImage);
			l0.texpaint.g4.setFloat(opacMergeMask, l1.getOpacity());
			l0.texpaint.g4.setInt(blendingMergeMask, l1.blending);
			l0.texpaint.g4.setVertexBuffer(ConstData.screenAlignedVB);
			l0.texpaint.g4.setIndexBuffer(ConstData.screenAlignedIB);
			l0.texpaint.g4.drawIndexedVertices();
			l0.texpaint.g4.end();
		}

		if (l1.isLayer()) {
			if (l1.paintBase) {
				l0.texpaint.g4.begin();
				l0.texpaint.g4.setPipeline(pipeMerge);
				l0.texpaint.g4.setTexture(tex0, l1.texpaint);
				l0.texpaint.g4.setTexture(tex1, empty);
				l0.texpaint.g4.setTexture(texmask, mask);
				l0.texpaint.g4.setTexture(texa, tempImage);
				l0.texpaint.g4.setFloat(opac, l1.getOpacity());
				l0.texpaint.g4.setInt(blending, l1.blending);
				l0.texpaint.g4.setVertexBuffer(ConstData.screenAlignedVB);
				l0.texpaint.g4.setIndexBuffer(ConstData.screenAlignedIB);
				l0.texpaint.g4.drawIndexedVertices();
				l0.texpaint.g4.end();
			}

			#if is_paint
			tempImage.g2.begin(false);
			tempImage.g2.pipeline = pipeCopy;
			tempImage.g2.drawImage(l0.texpaint_nor, 0, 0);
			tempImage.g2.pipeline = null;
			tempImage.g2.end();

			if (l1.paintNor) {
				l0.texpaint_nor.g4.begin();
				l0.texpaint_nor.g4.setPipeline(pipeMerge);
				l0.texpaint_nor.g4.setTexture(tex0, l1.texpaint);
				l0.texpaint_nor.g4.setTexture(tex1, l1.texpaint_nor);
				l0.texpaint_nor.g4.setTexture(texmask, mask);
				l0.texpaint_nor.g4.setTexture(texa, tempImage);
				l0.texpaint_nor.g4.setFloat(opac, l1.getOpacity());
				l0.texpaint_nor.g4.setInt(blending, l1.paintNorBlend ? -2 : -1);
				l0.texpaint_nor.g4.setVertexBuffer(ConstData.screenAlignedVB);
				l0.texpaint_nor.g4.setIndexBuffer(ConstData.screenAlignedIB);
				l0.texpaint_nor.g4.drawIndexedVertices();
				l0.texpaint_nor.g4.end();
			}

			tempImage.g2.begin(false);
			tempImage.g2.pipeline = pipeCopy;
			tempImage.g2.drawImage(l0.texpaint_pack, 0, 0);
			tempImage.g2.pipeline = null;
			tempImage.g2.end();

			if (l1.paintOcc || l1.paintRough || l1.paintMet || l1.paintHeight) {
				if (l1.paintOcc && l1.paintRough && l1.paintMet && l1.paintHeight) {
					commandsMergePack(pipeMerge, l0.texpaint_pack, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask, l1.paintHeightBlend ? -3 : -1);
				}
				else {
					if (l1.paintOcc) commandsMergePack(pipeMergeR, l0.texpaint_pack, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
					if (l1.paintRough) commandsMergePack(pipeMergeG, l0.texpaint_pack, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
					if (l1.paintMet) commandsMergePack(pipeMergeB, l0.texpaint_pack, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
				}
			}
			#end
		}
	}

	public static function flatten(heightToNormal = false, layers: Array<LayerSlot> = null): Dynamic {
		if (layers == null) layers = Project.layers;
		Base.makeTempImg();
		Base.makeExportImg();
		if (Base.pipeMerge == null) Base.makePipe();
		if (ConstData.screenAlignedVB == null) ConstData.createScreenAlignedData();
		var empty = RenderPath.active.renderTargets.get("empty_white").image;

		// Clear export layer
		Base.expa.g4.begin();
		Base.expa.g4.clear(Color.fromFloats(0.0, 0.0, 0.0, 0.0));
		Base.expa.g4.end();
		Base.expb.g4.begin();
		Base.expb.g4.clear(Color.fromFloats(0.5, 0.5, 1.0, 0.0));
		Base.expb.g4.end();
		Base.expc.g4.begin();
		Base.expc.g4.clear(Color.fromFloats(1.0, 0.0, 0.0, 0.0));
		Base.expc.g4.end();

		// Flatten layers
		for (l1 in layers) {
			if (!l1.isVisible()) continue;
			if (!l1.isLayer()) continue;

			var mask = empty;
			var l1masks = l1.getMasks();
			if (l1masks != null) {
				if (l1masks.length > 1) {
					Base.makeTempMaskImg();
					Base.tempMaskImage.g2.begin(true, 0x00000000);
					Base.tempMaskImage.g2.end();
					var l1 = { texpaint: Base.tempMaskImage };
					for (i in 0...l1masks.length) {
						Base.mergeLayer(untyped l1, l1masks[i]);
					}
					mask = Base.tempMaskImage;
				}
				else mask = l1masks[0].texpaint;
			}

			if (l1.paintBase) {
				Base.tempImage.g2.begin(false); // Copy to temp
				Base.tempImage.g2.pipeline = Base.pipeCopy;
				Base.tempImage.g2.drawImage(Base.expa, 0, 0);
				Base.tempImage.g2.pipeline = null;
				Base.tempImage.g2.end();

				Base.expa.g4.begin();
				Base.expa.g4.setPipeline(Base.pipeMerge);
				Base.expa.g4.setTexture(Base.tex0, l1.texpaint);
				Base.expa.g4.setTexture(Base.tex1, empty);
				Base.expa.g4.setTexture(Base.texmask, mask);
				Base.expa.g4.setTexture(Base.texa, Base.tempImage);
				Base.expa.g4.setFloat(Base.opac, l1.getOpacity());
				Base.expa.g4.setInt(Base.blending, layers.length > 1 ? l1.blending : 0);
				Base.expa.g4.setVertexBuffer(ConstData.screenAlignedVB);
				Base.expa.g4.setIndexBuffer(ConstData.screenAlignedIB);
				Base.expa.g4.drawIndexedVertices();
				Base.expa.g4.end();
			}

			#if is_paint
			if (l1.paintNor) {
				Base.tempImage.g2.begin(false);
				Base.tempImage.g2.pipeline = Base.pipeCopy;
				Base.tempImage.g2.drawImage(Base.expb, 0, 0);
				Base.tempImage.g2.pipeline = null;
				Base.tempImage.g2.end();

				Base.expb.g4.begin();
				Base.expb.g4.setPipeline(Base.pipeMerge);
				Base.expb.g4.setTexture(Base.tex0, l1.texpaint);
				Base.expb.g4.setTexture(Base.tex1, l1.texpaint_nor);
				Base.expb.g4.setTexture(Base.texmask, mask);
				Base.expb.g4.setTexture(Base.texa, Base.tempImage);
				Base.expb.g4.setFloat(Base.opac, l1.getOpacity());
				Base.expb.g4.setInt(Base.blending, l1.paintNorBlend ? -2 : -1);
				Base.expb.g4.setVertexBuffer(ConstData.screenAlignedVB);
				Base.expb.g4.setIndexBuffer(ConstData.screenAlignedIB);
				Base.expb.g4.drawIndexedVertices();
				Base.expb.g4.end();
			}

			if (l1.paintOcc || l1.paintRough || l1.paintMet || l1.paintHeight) {
				Base.tempImage.g2.begin(false);
				Base.tempImage.g2.pipeline = Base.pipeCopy;
				Base.tempImage.g2.drawImage(Base.expc, 0, 0);
				Base.tempImage.g2.pipeline = null;
				Base.tempImage.g2.end();

				if (l1.paintOcc && l1.paintRough && l1.paintMet && l1.paintHeight) {
					Base.commandsMergePack(Base.pipeMerge, Base.expc, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask, l1.paintHeightBlend ? -3 : -1);
				}
				else {
					if (l1.paintOcc) Base.commandsMergePack(Base.pipeMergeR, Base.expc, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
					if (l1.paintRough) Base.commandsMergePack(Base.pipeMergeG, Base.expc, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
					if (l1.paintMet) Base.commandsMergePack(Base.pipeMergeB, Base.expc, l1.texpaint, l1.texpaint_pack, l1.getOpacity(), mask);
				}
			}
			#end
		}

		#if krom_metal
		// Flush command list
		Base.expa.g2.begin(false);
		Base.expa.g2.end();
		Base.expb.g2.begin(false);
		Base.expb.g2.end();
		Base.expc.g2.begin(false);
		Base.expc.g2.end();
		#end

		var l0 = { texpaint: Base.expa, texpaint_nor: Base.expb, texpaint_pack: Base.expc };

		// Merge height map into normal map
		if (heightToNormal && MakeMaterial.heightUsed) {

			tempImage.g2.begin(false);
			tempImage.g2.pipeline = Base.pipeCopy;
			tempImage.g2.drawImage(l0.texpaint_nor, 0, 0);
			tempImage.g2.pipeline = null;
			tempImage.g2.end();

			l0.texpaint_nor.g4.begin();
			l0.texpaint_nor.g4.setPipeline(Base.pipeMerge);
			l0.texpaint_nor.g4.setTexture(Base.tex0, tempImage);
			l0.texpaint_nor.g4.setTexture(Base.tex1, l0.texpaint_pack);
			l0.texpaint_nor.g4.setTexture(Base.texmask, empty);
			l0.texpaint_nor.g4.setTexture(Base.texa, empty);
			l0.texpaint_nor.g4.setFloat(Base.opac, 1.0);
			l0.texpaint_nor.g4.setInt(Base.blending, -4);
			l0.texpaint_nor.g4.setVertexBuffer(ConstData.screenAlignedVB);
			l0.texpaint_nor.g4.setIndexBuffer(ConstData.screenAlignedIB);
			l0.texpaint_nor.g4.drawIndexedVertices();
			l0.texpaint_nor.g4.end();
		}

		return untyped l0;
	}

	public static function applyMask(l: LayerSlot, m: LayerSlot) {
		if (!l.isLayer() || !m.isMask()) return;

		if (Base.pipeMerge == null) Base.makePipe();
		Base.makeTempImg();

		// Copy layer to temp
		tempImage.g2.begin(false);
		tempImage.g2.pipeline = Base.pipeCopy;
		tempImage.g2.drawImage(l.texpaint, 0, 0);
		tempImage.g2.pipeline = null;
		tempImage.g2.end();

		// Apply mask
		if (ConstData.screenAlignedVB == null) ConstData.createScreenAlignedData();
		l.texpaint.g4.begin();
		l.texpaint.g4.setPipeline(Base.pipeApplyMask);
		l.texpaint.g4.setTexture(Base.tex0Mask, tempImage);
		l.texpaint.g4.setTexture(Base.texaMask, m.texpaint);
		l.texpaint.g4.setVertexBuffer(ConstData.screenAlignedVB);
		l.texpaint.g4.setIndexBuffer(ConstData.screenAlignedIB);
		l.texpaint.g4.drawIndexedVertices();
		l.texpaint.g4.end();
	}

	public static function commandsMergePack(pipe: PipelineState, i0: Image, i1: Image, i1pack: Image, i1maskOpacity: Float, i1texmask: Image, i1blending = -1) {
		i0.g4.begin();
		i0.g4.setPipeline(pipe);
		i0.g4.setTexture(tex0, i1);
		i0.g4.setTexture(tex1, i1pack);
		i0.g4.setTexture(texmask, i1texmask);
		i0.g4.setTexture(texa, tempImage);
		i0.g4.setFloat(opac, i1maskOpacity);
		i0.g4.setInt(blending, i1blending);
		i0.g4.setVertexBuffer(ConstData.screenAlignedVB);
		i0.g4.setIndexBuffer(ConstData.screenAlignedIB);
		i0.g4.drawIndexedVertices();
		i0.g4.end();
	}

	public static function isFillMaterial(): Bool {
		#if is_paint
		if (Context.raw.tool == ToolMaterial) return true;
		#end

		var m = Context.raw.material;
		for (l in Project.layers) if (l.fill_layer == m) return true;
		return false;
	}

	public static function updateFillLayers() {
		var _layer = Context.raw.layer;
		var _tool = Context.raw.tool;
		var _fillType = Context.raw.fillTypeHandle.position;
		var current: Graphics2 = null;

		#if is_paint
		if (Context.raw.tool == ToolMaterial) {
			if (RenderPathPaint.liveLayer == null) {
				RenderPathPaint.liveLayer = new arm.data.LayerSlot("_live");
			}

			current = Graphics2.current;
			if (current != null) current.end();

			Context.raw.tool = ToolFill;
			Context.raw.fillTypeHandle.position = FillObject;
			MakeMaterial.parsePaintMaterial(false);
			Context.raw.pdirty = 1;
			RenderPathPaint.useLiveLayer(true);
			RenderPathPaint.commandsPaint(false);
			RenderPathPaint.dilate(true, true);
			RenderPathPaint.useLiveLayer(false);
			Context.raw.tool = _tool;
			Context.raw.fillTypeHandle.position = _fillType;
			Context.raw.pdirty = 0;
			Context.raw.rdirty = 2;

			if (current != null) current.begin(false);
			return;
		}
		#end

		var hasFillLayer = false;
		var hasFillMask = false;
		for (l in Project.layers) if (l.isLayer() && l.fill_layer == Context.raw.material) hasFillLayer = true;
		for (l in Project.layers) if (l.isMask() && l.fill_layer == Context.raw.material) hasFillMask = true;

		if (hasFillLayer || hasFillMask) {
			current = Graphics2.current;
			if (current != null) current.end();
			Context.raw.pdirty = 1;
			Context.raw.tool = ToolFill;
			Context.raw.fillTypeHandle.position = FillObject;

			if (hasFillLayer) {
				var first = true;
				for (l in Project.layers) {
					if (l.isLayer() && l.fill_layer == Context.raw.material) {
						Context.raw.layer = l;
						if (first) {
							first = false;
							MakeMaterial.parsePaintMaterial(false);
						}
						setObjectMask();
						l.clear();
						RenderPathPaint.commandsPaint(false);
						RenderPathPaint.dilate(true, true);
					}
				}
			}
			if (hasFillMask) {
				var first = true;
				for (l in Project.layers) {
					if (l.isMask() && l.fill_layer == Context.raw.material) {
						Context.raw.layer = l;
						if (first) {
							first = false;
							MakeMaterial.parsePaintMaterial(false);
						}
						setObjectMask();
						l.clear();
						RenderPathPaint.commandsPaint(false);
						RenderPathPaint.dilate(true, true);
					}
				}
			}

			Context.raw.pdirty = 0;
			Context.raw.ddirty = 2;
			Context.raw.rdirty = 2;
			Context.raw.layersPreviewDirty = true; // Repaint all layer previews as multiple layers might have changed.
			if (current != null) current.begin(false);
			Context.raw.layer = _layer;
			setObjectMask();
			Context.raw.tool = _tool;
			Context.raw.fillTypeHandle.position = _fillType;
			MakeMaterial.parsePaintMaterial(false);
		}
	}

	public static function updateFillLayer(parsePaint = true) {
		var current = Graphics2.current;
		if (current != null) current.end();

		var _tool = Context.raw.tool;
		var _fillType = Context.raw.fillTypeHandle.position;
		Context.raw.tool = ToolFill;
		Context.raw.fillTypeHandle.position = FillObject;
		Context.raw.pdirty = 1;

		Context.raw.layer.clear();

		if (parsePaint) MakeMaterial.parsePaintMaterial(false);
		RenderPathPaint.commandsPaint(false);
		RenderPathPaint.dilate(true, true);

		Context.raw.rdirty = 2;
		Context.raw.tool = _tool;
		Context.raw.fillTypeHandle.position = _fillType;
		if (current != null) current.begin(false);
	}

	public static function setObjectMask() {
		#if is_sculpt
		return;
		#end

		var ar = [tr("None")];
		for (p in Project.paintObjects) ar.push(p.name);

		var mask = Context.objectMaskUsed() ? Context.raw.layer.getObjectMask() : 0;
		if (Context.layerFilterUsed()) mask = Context.raw.layerFilter;
		if (mask > 0) {
			if (Context.raw.mergedObject != null) {
				Context.raw.mergedObject.visible = false;
			}
			var o = Project.paintObjects[0];
			for (p in Project.paintObjects) {
				if (p.name == ar[mask]) {
					o = p;
					break;
				}
			}
			Context.selectPaintObject(o);
		}
		else {
			var isAtlas = Context.raw.layer.getObjectMask() > 0 && Context.raw.layer.getObjectMask() <= Project.paintObjects.length;
			if (Context.raw.mergedObject == null || isAtlas || Context.raw.mergedObjectIsAtlas) {
				var visibles = isAtlas ? Project.getAtlasObjects(Context.raw.layer.getObjectMask()) : null;
				MeshUtil.mergeMesh(visibles);
			}
			Context.selectPaintObject(Context.mainObject());
			Context.raw.paintObject.skip_context = "paint";
			Context.raw.mergedObject.visible = true;
		}
		UVUtil.dilatemapCached = false;
	}

	public static function newLayer(clear = true, position = -1): LayerSlot {
		if (Project.layers.length > maxLayers) return null;
		var l = new LayerSlot();
		l.objectMask = Context.raw.layerFilter;
		if (position == -1) {
			if (Context.raw.layer.isMask()) Context.setLayer(Context.raw.layer.parent);
			Project.layers.insert(Project.layers.indexOf(Context.raw.layer) + 1, l);
		}
		else {
			Project.layers.insert(position, l);
		}

		Context.setLayer(l);
		var li = Project.layers.indexOf(Context.raw.layer);
		if (li > 0) {
			var below = Project.layers[li - 1];
			if (below.isLayer()) {
				Context.raw.layer.parent = below.parent;
			}
		}
		if (clear) App.notifyOnInit(function() { l.clear(); });
		Context.raw.layerPreviewDirty = true;
		return l;
	}

	public static function newMask(clear = true, parent: LayerSlot, position = -1): LayerSlot {
		if (Project.layers.length > maxLayers) return null;
		var l = new LayerSlot("", SlotMask, parent);
		if (position == -1) position = Project.layers.indexOf(parent);
		Project.layers.insert(position, l);
		Context.setLayer(l);
		if (clear) App.notifyOnInit(function() { l.clear(); });
		Context.raw.layerPreviewDirty = true;
		return l;
	}

	public static function newGroup(): LayerSlot {
		if (Project.layers.length > maxLayers) return null;
		var l = new LayerSlot("", SlotGroup);
		Project.layers.push(l);
		Context.setLayer(l);
		return l;
	}

	public static function createFillLayer(uvType = UVMap, decalMat: Mat4 = null, position = -1) {
		function _init() {
			var l = newLayer(false, position);
			History.newLayer();
			l.uvType = uvType;
			if (decalMat != null) l.decalMat = decalMat;
			l.objectMask = Context.raw.layerFilter;
			History.toFillLayer();
			l.toFillLayer();
		}
		App.notifyOnInit(_init);
	}

	public static function createImageMask(asset: TAsset) {
		var l = Context.raw.layer;
		if (l.isMask() || l.isGroup()) {
			return;
		}

		History.newLayer();
		var m = Base.newMask(false, l);
		m.clear(0x00000000, Project.getImage(asset));
		Context.raw.layerPreviewDirty = true;
	}

	public static function createColorLayer(baseColor: Int, occlusion = 1.0, roughness = Base.defaultRough, metallic = 0.0, position = -1) {
		function _init() {
			var l = newLayer(false, position);
			History.newLayer();
			l.uvType = UVMap;
			l.objectMask = Context.raw.layerFilter;
			l.clear(baseColor, occlusion, roughness, metallic);
		}
		App.notifyOnInit(_init);
	}

	public static function onLayersResized() {
		App.notifyOnInit(function() {
			Base.resizeLayers();
			var _layer = Context.raw.layer;
			var _material = Context.raw.material;
			for (l in arm.Project.layers) {
				if (l.fill_layer != null) {
					Context.raw.layer = l;
					Context.raw.material = l.fill_layer;
					Base.updateFillLayer();
				}
			}
			Context.raw.layer = _layer;
			Context.raw.material = _material;
			MakeMaterial.parsePaintMaterial();
		});
		UVUtil.uvmap = null;
		UVUtil.uvmapCached = false;
		UVUtil.trianglemap = null;
		UVUtil.trianglemapCached = false;
		UVUtil.dilatemapCached = false;
		#if (krom_direct3d12 || krom_vulkan || krom_metal)
		arm.render.RenderPathRaytrace.ready = false;
		#end
	}
	#end

	#if is_lab
	public static function flatten(heightToNormal = false): Dynamic {
		var texpaint = arm.logic.BrushOutputNode.inst.texpaint;
		var texpaint_nor = arm.logic.BrushOutputNode.inst.texpaint_nor;
		var texpaint_pack = arm.logic.BrushOutputNode.inst.texpaint_pack;

		var nodes = UINodes.inst.getNodes();
		var canvas = UINodes.inst.getCanvas(true);
		if (nodes.nodesSelectedId.length > 0) {
			var node = nodes.getNode(canvas.nodes, nodes.nodesSelectedId[0]);
			var brushNode = arm.logic.LogicParser.getLogicNode(node);
			if (brushNode != null && brushNode.getCachedImage() != null) {
				texpaint = brushNode.getCachedImage();
				texpaint_nor = RenderPath.active.renderTargets.get("texpaint_nor_empty").image;
				texpaint_pack = RenderPath.active.renderTargets.get("texpaint_pack_empty").image;
			}
		}

		return { texpaint: texpaint, texpaint_nor: texpaint_nor, texpaint_pack: texpaint_pack };
	}

	public static function onLayersResized() {
		arm.logic.BrushOutputNode.inst.texpaint.unload();
		arm.logic.BrushOutputNode.inst.texpaint = RenderPath.active.renderTargets.get("texpaint").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY());
		arm.logic.BrushOutputNode.inst.texpaint_nor.unload();
		arm.logic.BrushOutputNode.inst.texpaint_nor = RenderPath.active.renderTargets.get("texpaint_nor").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY());
		arm.logic.BrushOutputNode.inst.texpaint_pack.unload();
		arm.logic.BrushOutputNode.inst.texpaint_pack = RenderPath.active.renderTargets.get("texpaint_pack").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY());

		if (arm.logic.InpaintNode.image != null) {
			arm.logic.InpaintNode.image.unload();
			arm.logic.InpaintNode.image = null;
			arm.logic.InpaintNode.mask.unload();
			arm.logic.InpaintNode.mask = null;
			arm.logic.InpaintNode.init();
		}

		if (arm.logic.PhotoToPBRNode.images != null) {
			for (image in arm.logic.PhotoToPBRNode.images) image.unload();
			arm.logic.PhotoToPBRNode.images = null;
			arm.logic.PhotoToPBRNode.init();
		}

		if (arm.logic.TilingNode.image != null) {
			arm.logic.TilingNode.image.unload();
			arm.logic.TilingNode.image = null;
			arm.logic.TilingNode.init();
		}

		RenderPath.active.renderTargets.get("texpaint_blend0").image.unload();
		RenderPath.active.renderTargets.get("texpaint_blend0").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);
		RenderPath.active.renderTargets.get("texpaint_blend1").image.unload();
		RenderPath.active.renderTargets.get("texpaint_blend1").image = Image.createRenderTarget(Config.getTextureResX(), Config.getTextureResY(), TextureFormat.R8);

		if (RenderPath.active.renderTargets.get("texpaint_node") != null) {
			RenderPath.active.renderTargets.remove("texpaint_node");
		}
		if (RenderPath.active.renderTargets.get("texpaint_node_target") != null) {
			RenderPath.active.renderTargets.remove("texpaint_node_target");
		}

		Base.notifyOnNextFrame(function() {
			initLayers();
		});

		#if (krom_direct3d12 || krom_vulkan || krom_metal)
		arm.render.RenderPathRaytrace.ready = false;
		#end
	}
	#end

	public static var defaultKeymap = {
		action_paint: "left",
		action_rotate: "alt+left",
		action_pan: "alt+middle",
		action_zoom: "alt+right",
		rotate_light: "shift+middle",
		rotate_envmap: "ctrl+middle",
		set_clone_source: "alt",
		stencil_transform: "ctrl",
		stencil_hide: "z",
		brush_radius: "f",
		brush_radius_decrease: "[",
		brush_radius_increase: "]",
		brush_ruler: "shift",
		file_new: "ctrl+n",
		file_open: "ctrl+o",
		file_open_recent: "ctrl+shift+o",
		file_save: "ctrl+s",
		file_save_as: "ctrl+shift+s",
		file_reimport_mesh: "ctrl+r",
		file_reimport_textures: "ctrl+shift+r",
		file_import_assets: "ctrl+i",
		file_export_textures: "ctrl+e",
		file_export_textures_as: "ctrl+shift+e",
		edit_undo: "ctrl+z",
		edit_redo: "ctrl+shift+z",
		edit_prefs: "ctrl+k",
		view_reset: "0",
		view_front: "1",
		view_back: "ctrl+1",
		view_right: "3",
		view_left: "ctrl+3",
		view_top: "7",
		view_bottom: "ctrl+7",
		view_camera_type: "5",
		view_orbit_left: "4",
		view_orbit_right: "6",
		view_orbit_up: "8",
		view_orbit_down: "2",
		view_orbit_opposite: "9",
		view_zoom_in: "",
		view_zoom_out: "",
		view_distract_free: "f11",
		viewport_mode: "ctrl+m",
		toggle_node_editor: "tab",
		toggle_2d_view: "shift+tab",
		toggle_browser: "`",
		node_search: "space",
		operator_search: "space",

		#if (is_paint || is_sculpt)
		decal_mask: "ctrl",
		select_material: "shift+number",
		select_layer: "alt+number",
		brush_opacity: "shift+f",
		brush_angle: "alt+f",
		tool_brush: "b",
		tool_eraser: "e",
		tool_fill: "g",
		tool_decal: "d",
		tool_text: "t",
		tool_clone: "l",
		tool_blur: "u",
		tool_smudge: "m",
		tool_particle: "p",
		tool_colorid: "c",
		tool_picker: "v",
		tool_bake: "k",
		tool_gizmo: "",
		tool_material: "",
		swap_brush_eraser: "",
		#end
	};
}