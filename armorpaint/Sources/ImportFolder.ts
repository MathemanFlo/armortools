
class ImportFolder {

	static run = (path: string) => {
		let files = File.read_directory(path);
		let mapbase = "";
		let mapopac = "";
		let mapnor = "";
		let mapocc = "";
		let maprough = "";
		let mapmet = "";
		let mapheight = "";

		let foundTexture = false;
		// Import maps
		for (let f of files) {
			if (!Path.is_texture(f)) continue;

			// TODO: handle -albedo

			let base = f.substr(0, f.lastIndexOf(".")).toLowerCase();
			let valid = false;
			if (mapbase == "" && Path.is_base_color_tex(base)) {
				mapbase = f;
				valid = true;
			}
			if (mapopac == "" && Path.is_opacity_tex(base)) {
				mapopac = f;
				valid = true;
			}
			if (mapnor == "" && Path.is_normal_map_tex(base)) {
				mapnor = f;
				valid = true;
			}
			if (mapocc == "" && Path.is_occlusion_tex(base)) {
				mapocc = f;
				valid = true;
			}
			if (maprough == "" && Path.is_roughness_tex(base)) {
				maprough = f;
				valid = true;
			}
			if (mapmet == "" && Path.is_metallic_tex(base)) {
				mapmet = f;
				valid = true;
			}
			if (mapheight == "" && Path.is_displacement_tex(base)) {
				mapheight = f;
				valid = true;
			}

			if (valid) {
				ImportTexture.run(path + Path.sep + f, false);
				foundTexture = true;
			}
		}

		if (!foundTexture) {
			Console.info(tr("Folder does not contain textures"));
			return;
		}

		// Create material
		Context.raw.material = SlotMaterial.create(Project.materials[0].data);
		Project.materials.push(Context.raw.material);
		let nodes = Context.raw.material.nodes;
		let canvas = Context.raw.material.canvas;
		let dirs = path.split(Path.sep);
		canvas.name = dirs[dirs.length - 1];
		let nout: zui_node_t = null;
		for (let n of canvas.nodes) {
			if (n.type == "OUTPUT_MATERIAL_PBR") {
				nout = n;
				break;
			}
		}
		for (let n of canvas.nodes) {
			if (n.name == "RGB") {
				zui_remove_node(n, canvas);
				break;
			}
		}

		// Place nodes
		let pos = 0;
		let startY = 100;
		let nodeH = 164;
		if (mapbase != "") {
			ImportFolder.place_image_node(nodes, canvas, mapbase, startY + nodeH * pos, nout.id, 0);
			pos++;
		}
		if (mapopac != "") {
			ImportFolder.place_image_node(nodes, canvas, mapopac, startY + nodeH * pos, nout.id, 1);
			pos++;
		}
		if (mapocc != "") {
			ImportFolder.place_image_node(nodes, canvas, mapocc, startY + nodeH * pos, nout.id, 2);
			pos++;
		}
		if (maprough != "") {
			ImportFolder.place_image_node(nodes, canvas, maprough, startY + nodeH * pos, nout.id, 3);
			pos++;
		}
		if (mapmet != "") {
			ImportFolder.place_image_node(nodes, canvas, mapmet, startY + nodeH * pos, nout.id, 4);
			pos++;
		}
		if (mapnor != "") {
			ImportFolder.place_image_node(nodes, canvas, mapnor, startY + nodeH * pos, nout.id, 5);
			pos++;
		}
		if (mapheight != "") {
			ImportFolder.place_image_node(nodes, canvas, mapheight, startY + nodeH * pos, nout.id, 7);
			pos++;
		}

		MakeMaterial.parse_paint_material();
		UtilRender.make_material_preview();
		UIBase.hwnds[1].redraws = 2;
		History.new_material();
	}

	static place_image_node = (nodes: zui_nodes_t, canvas: zui_node_canvas_t, asset: string, ny: i32, to_id: i32, to_socket: i32) => {
		let n = NodesMaterial.create_node("TEX_IMAGE");
		n.buttons[0].default_value = Base.get_asset_index(asset);
		n.x = 72;
		n.y = ny;
		let l: zui_node_link_t = { id: zui_get_link_id(canvas.links), from_id: n.id, from_socket: 0, to_id: to_id, to_socket: to_socket };
		canvas.links.push(l);
	}
}
