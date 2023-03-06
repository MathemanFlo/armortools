package arm.logic;

import arm.logic.LogicNode;
import arm.shader.MakeMaterial;
import arm.ui.UIToolbar;
import arm.ui.UISidebar;
import arm.ui.UIView2D;

@:keep
class BrushOutputNode extends LogicNode {

	public var Directional = false; // button 0

	public function new(tree: LogicTree) {
		super(tree);
		Context.raw.runBrush = run;
		Context.raw.parseBrushInputs = parseInputs;
	}

	function parseInputs() {
		var lastMask = Context.raw.brushMaskImage;
		var lastStencil = Context.raw.brushStencilImage;

		var input0: Dynamic;
		var input1: Dynamic;
		var input2: Dynamic;
		var input3: Dynamic;
		var input4: Dynamic;
		var input5: Dynamic;
		var input6: Dynamic;
		try {
			inputs[0].get(function(value) { input0 = value; });
			inputs[1].get(function(value) { input1 = value; });
			inputs[2].get(function(value) { input2 = value; });
			inputs[3].get(function(value) { input3 = value; });
			inputs[4].get(function(value) { input4 = value; });
			inputs[5].get(function(value) { input5 = value; });
			inputs[6].get(function(value) { input6 = value; });
		}
		catch (_) {
			return;
		}

		Context.raw.paintVec = input0;
		Context.raw.brushNodesRadius = input1;
		Context.raw.brushNodesScale = input2;
		Context.raw.brushNodesAngle = input3;

		var opac: Dynamic = input4; // Float or texture name
		if (opac == null) opac = 1.0;
		if (Std.isOfType(opac, String)) {
			Context.raw.brushMaskImageIsAlpha = opac.endsWith(".a");
			opac = opac.substr(0, opac.lastIndexOf("."));
			Context.raw.brushNodesOpacity = 1.0;
			var index = Project.assetNames.indexOf(opac);
			var asset = Project.assets[index];
			Context.raw.brushMaskImage = Project.getImage(asset);
		}
		else {
			Context.raw.brushNodesOpacity = opac;
			Context.raw.brushMaskImage = null;
		}

		Context.raw.brushNodesHardness = input5;

		var stencil: Dynamic = input6; // Float or texture name
		if (stencil == null) stencil = 1.0;
		if (Std.isOfType(stencil, String)) {
			Context.raw.brushStencilImageIsAlpha = stencil.endsWith(".a");
			stencil = stencil.substr(0, stencil.lastIndexOf("."));
			var index = Project.assetNames.indexOf(stencil);
			var asset = Project.assets[index];
			Context.raw.brushStencilImage = Project.getImage(asset);
		}
		else {
			Context.raw.brushStencilImage = null;
		}

		if (lastMask != Context.raw.brushMaskImage ||
			lastStencil != Context.raw.brushStencilImage) {
			MakeMaterial.parsePaintMaterial();
		}

		Context.raw.brushDirectional = Directional;
	}

	function run(from: Int) {
		var left = 0.0;
		var right = 1.0;
		if (Context.raw.paint2d) {
			left = 1.0;
			right = (Context.raw.splitView ? 2.0 : 1.0) + UIView2D.inst.ww / App.w();
		}

		// First time init
		if (Context.raw.lastPaintX < 0 || Context.raw.lastPaintY < 0) {
			Context.raw.lastPaintVecX = Context.raw.paintVec.x;
			Context.raw.lastPaintVecY = Context.raw.paintVec.y;
		}

		// Do not paint over fill layer
		var fillLayer = Context.raw.layer.fill_layer != null && Context.raw.tool != ToolPicker && Context.raw.tool != ToolColorId;

		// Do not paint over groups
		var groupLayer = Context.raw.layer.isGroup();

		// Paint bounds
		if (Context.raw.paintVec.x > left &&
			Context.raw.paintVec.x < right &&
			Context.raw.paintVec.y > 0 &&
			Context.raw.paintVec.y < 1 &&
			!fillLayer &&
			!groupLayer &&
			(Context.raw.layer.isVisible() || Context.raw.paint2d) &&
			!UISidebar.inst.ui.isHovered &&
			!arm.App.isDragging &&
			!arm.App.isResizing &&
			!arm.App.isScrolling() &&
			!arm.App.isComboSelected()) {

			// Set color pick
			var down = iron.system.Input.getMouse().down() || iron.system.Input.getPen().down();
			if (down && Context.raw.tool == ToolColorId && Project.assets.length > 0) {
				Context.raw.colorIdPicked = true;
				UIToolbar.inst.toolbarHandle.redraws = 1;
			}

			// Prevent painting the same spot
			var sameSpot = Context.raw.paintVec.x == Context.raw.lastPaintX && Context.raw.paintVec.y == Context.raw.lastPaintY;
			var lazy = Context.raw.tool == ToolBrush && Context.raw.brushLazyRadius > 0;
			if (down && (sameSpot || lazy)) {
				Context.raw.painted++;
			}
			else {
				Context.raw.painted = 0;
			}
			Context.raw.lastPaintX = Context.raw.paintVec.x;
			Context.raw.lastPaintY = Context.raw.paintVec.y;

			if (Context.raw.tool == ToolParticle) {
				Context.raw.painted = 0; // Always paint particles
			}

			if (Context.raw.painted == 0) {
				parseInputs();
			}

			if (Context.raw.painted <= 1) {
				Context.raw.pdirty = 1;
				Context.raw.rdirty = 2;
			}
		}
	}

	// public static var def: TNode = {
	// 	id: 0,
	// 	name: _tr("Brush Output"),
	// 	type: "BrushOutputNode",
	// 	x: 0,
	// 	y: 0,
	// 	color: 0xff4982a0,
	// 	inputs: [
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Position"),
	// 			type: "VECTOR",
	// 			color: 0xff63c763,
	// 			default_value: f32([0.0, 0.0, 0.0])
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Radius"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 1.0
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Scale"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 1.0
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Angle"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 0.0
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Opacity"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 1.0
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Hardness"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 1.0
	// 		},
	// 		{
	// 			id: 0,
	// 			node_id: 0,
	// 			name: _tr("Stencil"),
	// 			type: "VALUE",
	// 			color: 0xffa1a1a1,
	// 			default_value: 1.0
	// 		}
	// 	],
	// 	outputs: [],
	// 	buttons: [
	// 		{
	// 			name: _tr("Directional"),
	// 			type: "BOOL",
	// 			default_value: false,
	// 			output: 0
	// 		}
	// 	]
	// };
}