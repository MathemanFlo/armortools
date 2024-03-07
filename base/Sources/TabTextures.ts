
class TabTextures {

	static draw = (htab: zui_handle_t) => {
		let ui: zui_t = UIBase.ui;
		let statush: i32 = Config.raw.layout[layout_size_t.STATUS_H];
		if (zui_tab(htab, tr("Textures")) && statush > UIStatus.default_status_h * zui_SCALE(ui)) {

			zui_begin_sticky();

			if (Config.raw.touch_ui) {
				zui_row([1 / 4, 1 / 4]);
			}
			else {
				zui_row([1 / 14, 1 / 14]);
			}

			if (zui_button(tr("Import"))) {
				UIFiles.show(Path.texture_formats.join(","), false, true, (path: string) => {
					ImportAsset.run(path, -1.0, -1.0, true, false);
					UIBase.hwnds[tab_area_t.STATUS].redraws = 2;
				});
			}
			if (ui.is_hovered) zui_tooltip(tr("Import texture file") + ` (${Config.keymap.file_import_assets})`);

			if (zui_button(tr("2D View"))) UIBase.show_2d_view(view_2d_type_t.ASSET);

			zui_end_sticky();

			if (Project.assets.length > 0) {

				///if (is_paint || is_sculpt)
				let statusw: i32 = sys_width() - UIToolbar.toolbar_w - Config.raw.layout[layout_size_t.SIDEBAR_W];
				///end
				///if is_lab
				let statusw: i32 = sys_width();
				///end

				let slotw: i32 = Math.floor(52 * zui_SCALE(ui));
				let num: i32 = Math.floor(statusw / slotw);

				for (let row: i32 = 0; row < Math.floor(Math.ceil(Project.assets.length / num)); ++row) {
					let mult: i32 = Config.raw.show_asset_names ? 2 : 1;
					let ar: f32[] = [];
					for (let i: i32 = 0; i < num * mult; ++i) ar.push(1 / num);
					zui_row(ar);

					ui._x += 2;
					let off: f32 = Config.raw.show_asset_names ? zui_ELEMENT_OFFSET(ui) * 10.0 : 6;
					if (row > 0) ui._y += off;

					for (let j: i32 = 0; j < num; ++j) {
						let imgw: i32 = Math.floor(50 * zui_SCALE(ui));
						let i: i32 = j + row * num;
						if (i >= Project.assets.length) {
							zui_end_element(imgw);
							if (Config.raw.show_asset_names) zui_end_element(0);
							continue;
						}

						let asset: asset_t = Project.assets[i];
						let img: image_t = Project.get_image(asset);
						let uix: f32 = ui._x;
						let uiy: f32 = ui._y;
						let sw: i32 = img.height < img.width ? img.height : 0;
						if (zui_image(img, 0xffffffff, slotw, 0, 0, sw, sw) == zui_state_t.STARTED && ui.input_y > ui._window_y) {
							Base.drag_off_x = -(mouse_x - uix - ui._window_x - 3);
							Base.drag_off_y = -(mouse_y - uiy - ui._window_y + 1);
							Base.drag_asset = asset;
							Context.raw.texture = asset;

							if (time_time() - Context.raw.select_time < 0.25) UIBase.show_2d_view(view_2d_type_t.ASSET);
							Context.raw.select_time = time_time();
							UIView2D.hwnd.redraws = 2;
						}

						if (asset == Context.raw.texture) {
							let _uix: f32 = ui._x;
							let _uiy: f32 = ui._y;
							ui._x = uix;
							ui._y = uiy;
							let off: i32 = i % 2 == 1 ? 1 : 0;
							let w: i32 = 50;
							zui_fill(0,               0, w + 3,       2, ui.t.HIGHLIGHT_COL);
							zui_fill(0,     w - off + 2, w + 3, 2 + off, ui.t.HIGHLIGHT_COL);
							zui_fill(0,               0,     2,   w + 3, ui.t.HIGHLIGHT_COL);
							zui_fill(w + 2,           0,     2,   w + 4, ui.t.HIGHLIGHT_COL);
							ui._x = _uix;
							ui._y = _uiy;
						}

						let isPacked: bool = Project.raw.packed_assets != null && Project.packed_asset_exists(Project.raw.packed_assets, asset.file);

						if (ui.is_hovered) {
							zui_tooltip_image(img, 256);
							zui_tooltip(asset.name + (isPacked ? " " + tr("(packed)") : ""));
						}

						if (ui.is_hovered && ui.input_released_r) {
							Context.raw.texture = asset;

							let count: i32 = 0;

							///if (is_paint || is_sculpt)
							count = isPacked ? 6 : 8;
							///end
							///if is_lab
							count = isPacked ? 6 : 6;
							///end

							UIMenu.draw((ui: zui_t) => {
								if (UIMenu.menu_button(ui, tr("Export"))) {
									UIFiles.show("png", true, false, (path: string) => {
										Base.notify_on_next_frame(() => {
											///if (is_paint || is_sculpt)
											if (Base.pipe_merge == null) Base.make_pipe();
											///end
											///if is_lab
											if (Base.pipe_copy == null) Base.make_pipe();
											///end

											let target: image_t = image_create_render_target(TabTextures.to_pow2(img.width), TabTextures.to_pow2(img.height));
											g2_begin(target);
											g2_set_pipeline(Base.pipe_copy);
											g2_draw_scaled_image(img, 0, 0, target.width, target.height);
											g2_set_pipeline(null);
											g2_end();
											Base.notify_on_next_frame(() => {
												let f: string = UIFiles.filename;
												if (f == "") f = tr("untitled");
												if (!f.endsWith(".png")) f += ".png";
												krom_write_png(path + Path.sep + f, image_get_pixels(target), target.width, target.height, 0);
												image_unload(target);
											});
										});
									});
								}
								if (UIMenu.menu_button(ui, tr("Reimport"))) {
									Project.reimport_texture(asset);
								}

								///if (is_paint || is_sculpt)
								if (UIMenu.menu_button(ui, tr("To Mask"))) {
									Base.notify_on_next_frame(() => {
										Base.create_image_mask(asset);
									});
								}
								///end

								if (UIMenu.menu_button(ui, tr("Set as Envmap"))) {
									Base.notify_on_next_frame(() => {
										ImportEnvmap.run(asset.file, img);
									});
								}

								///if is_paint
								if (UIMenu.menu_button(ui, tr("Set as Color ID Map"))) {
									Context.raw.colorid_handle.position = i;
									Context.raw.colorid_picked = false;
									UIToolbar.toolbar_handle.redraws = 1;
									if (Context.raw.tool == workspace_tool_t.COLORID) {
										UIHeader.header_handle.redraws = 2;
										Context.raw.ddirty = 2;
									}
								}
								///end

								if (UIMenu.menu_button(ui, tr("Delete"), "delete")) {
									TabTextures.delete_texture(asset);
								}
								if (!isPacked && UIMenu.menu_button(ui, tr("Open Containing Directory..."))) {
									File.start(asset.file.substr(0, asset.file.lastIndexOf(Path.sep)));
								}
								if (!isPacked && UIMenu.menu_button(ui, tr("Open in Browser"))) {
									TabBrowser.show_directory(asset.file.substr(0, asset.file.lastIndexOf(Path.sep)));
								}
							}, count);
						}

						if (Config.raw.show_asset_names) {
							ui._x = uix;
							ui._y += slotw * 0.9;
							zui_text(Project.assets[i].name, zui_align_t.CENTER);
							if (ui.is_hovered) zui_tooltip(Project.assets[i].name);
							ui._y -= slotw * 0.9;
							if (i == Project.assets.length - 1) {
								ui._y += j == num - 1 ? imgw : imgw + zui_ELEMENT_H(ui) + zui_ELEMENT_OFFSET(ui);
							}
						}
					}
				}
			}
			else {
				let img: image_t = Res.get("icons.k");
				let r: rect_t = Res.tile50(img, 0, 1);
				zui_image(img, ui.t.BUTTON_COL, r.h, r.x, r.y, r.w, r.h);
				if (ui.is_hovered) zui_tooltip(tr("Drag and drop files here"));
			}

			let inFocus: bool = ui.input_x > ui._window_x && ui.input_x < ui._window_x + ui._window_w &&
						 	 	ui.input_y > ui._window_y && ui.input_y < ui._window_y + ui._window_h;
			if (inFocus && ui.is_delete_down && Project.assets.length > 0 && Project.assets.indexOf(Context.raw.texture) >= 0) {
				ui.is_delete_down = false;
				TabTextures.delete_texture(Context.raw.texture);
			}
		}
	}

	static to_pow2 = (i: i32): i32 => {
		i--;
		i |= i >> 1;
		i |= i >> 2;
		i |= i >> 4;
		i |= i >> 8;
		i |= i >> 16;
		i++;
		return i;
	}

	static update_texture_pointers = (nodes: zui_node_t[], i: i32) => {
		for (let n of nodes) {
			if (n.type == "TEX_IMAGE") {
				if (n.buttons[0].default_value == i) {
					n.buttons[0].default_value = 9999; // Texture deleted, use pink now
				}
				else if (n.buttons[0].default_value > i) {
					n.buttons[0].default_value--; // Offset by deleted texture
				}
			}
		}
	}

	static delete_texture = (asset: asset_t) => {
		let i: i32 = Project.assets.indexOf(asset);
		if (Project.assets.length > 1) {
			Context.raw.texture = Project.assets[i == Project.assets.length - 1 ? i - 1 : i + 1];
		}
		UIBase.hwnds[tab_area_t.STATUS].redraws = 2;

		///if is_paint
		if (Context.raw.tool == workspace_tool_t.COLORID && i == Context.raw.colorid_handle.position) {
			UIHeader.header_handle.redraws = 2;
			Context.raw.ddirty = 2;
			Context.raw.colorid_picked = false;
			UIToolbar.toolbar_handle.redraws = 1;
		}
		///end

		data_delete_image(asset.file);
		Project.asset_map.delete(asset.id);
		Project.assets.splice(i, 1);
		Project.asset_names.splice(i, 1);
		let _next = () => {
			MakeMaterial.parse_paint_material();

			///if (is_paint || is_sculpt)
			UtilRender.make_material_preview();
			UIBase.hwnds[tab_area_t.SIDEBAR1].redraws = 2;
			///end
		}
		Base.notify_on_next_frame(_next);

		for (let m of Project.materials) TabTextures.update_texture_pointers(m.canvas.nodes, i);
		///if (is_paint || is_sculpt)
		for (let b of Project.brushes) TabTextures.update_texture_pointers(b.canvas.nodes, i);
		///end
	}
}
