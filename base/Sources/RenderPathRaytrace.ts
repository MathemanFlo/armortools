
///if (krom_direct3d12 || krom_vulkan || krom_metal)

class RenderPathRaytrace {

	static frame: i32 = 0;
	static ready: bool = false;
	static dirty: i32 = 0;
	static uv_scale: f32 = 1.0;
	static first: bool = true;
	static f32a: Float32Array = new Float32Array(24);
	static help_mat: mat4_t = mat4_identity();
	static vb_scale: f32 = 1.0;
	static vb: vertex_buffer_t;
	static ib: index_buffer_t;

	static last_envmap: image_t = null;
	static is_bake: bool = false;

	///if krom_direct3d12
	static ext: string = ".cso";
	///elseif krom_metal
	static ext: string = ".metal";
	///else
	static ext: string = ".spirv";
	///end

	///if is_lab
	static last_texpaint: image_t = null;
	///end

	static init = () => {
	}

	static commands = (useLiveLayer: bool) => {
		if (!RenderPathRaytrace.ready || RenderPathRaytrace.is_bake) {
			RenderPathRaytrace.ready = true;
			RenderPathRaytrace.is_bake = false;
			let mode: string = Context.raw.pathtrace_mode == path_trace_mode_t.CORE ? "core" : "full";
			RenderPathRaytrace.raytrace_init("raytrace_brute_" + mode + RenderPathRaytrace.ext);
			RenderPathRaytrace.last_envmap = null;
		}

		if (!Context.raw.envmap_loaded) {
			Context.load_envmap();
			Context.update_envmap();
		}

		let probe: world_data_t = scene_world;
		let savedEnvmap: image_t = Context.raw.show_envmap_blur ? probe._.radiance_mipmaps[0] : Context.raw.saved_envmap;

		if (RenderPathRaytrace.last_envmap != savedEnvmap) {
			RenderPathRaytrace.last_envmap = savedEnvmap;

			let bnoise_sobol: image_t = scene_embedded.get("bnoise_sobol.k");
			let bnoise_scramble: image_t = scene_embedded.get("bnoise_scramble.k");
			let bnoise_rank: image_t = scene_embedded.get("bnoise_rank.k");

			let l: any = Base.flatten(true);
			krom_raytrace_set_textures(l.texpaint, l.texpaint_nor, l.texpaint_pack, savedEnvmap.texture_, bnoise_sobol.texture_, bnoise_scramble.texture_, bnoise_rank.texture_);
		}

		///if is_lab
		let l: any = Base.flatten(true);
		if (l.texpaint != RenderPathRaytrace.last_texpaint) {
			RenderPathRaytrace.last_texpaint = l.texpaint;

			let bnoise_sobol: image_t = scene_embedded.get("bnoise_sobol.k");
			let bnoise_scramble: image_t = scene_embedded.get("bnoise_scramble.k");
			let bnoise_rank: image_t = scene_embedded.get("bnoise_rank.k");

			krom_raytrace_set_textures(l.texpaint, l.texpaint_nor, l.texpaint_pack, savedEnvmap.texture_, bnoise_sobol.texture_, bnoise_scramble.texture_, bnoise_rank.texture_);
		}
		///end

		if (Context.raw.pdirty > 0 || RenderPathRaytrace.dirty > 0) {
			Base.flatten(true);
		}

		let cam: camera_object_t = scene_camera;
		let ct: transform_t = cam.base.transform;
		mat4_set_from(RenderPathRaytrace.help_mat, cam.v);
		mat4_mult_mat(RenderPathRaytrace.help_mat, cam.p);
		mat4_get_inv(RenderPathRaytrace.help_mat, RenderPathRaytrace.help_mat);
		RenderPathRaytrace.f32a[0] = transform_world_x(ct);
		RenderPathRaytrace.f32a[1] = transform_world_y(ct);
		RenderPathRaytrace.f32a[2] = transform_world_z(ct);
		RenderPathRaytrace.f32a[3] = RenderPathRaytrace.frame;
		///if krom_metal
		// frame = (frame % (16)) + 1; // _PAINT
		RenderPathRaytrace.frame = RenderPathRaytrace.frame + 1; // _RENDER
		///else
		RenderPathRaytrace.frame = (RenderPathRaytrace.frame % 4) + 1; // _PAINT
		// frame = frame + 1; // _RENDER
		///end
		RenderPathRaytrace.f32a[4] = RenderPathRaytrace.help_mat.m[0];
		RenderPathRaytrace.f32a[5] = RenderPathRaytrace.help_mat.m[1];
		RenderPathRaytrace.f32a[6] = RenderPathRaytrace.help_mat.m[2];
		RenderPathRaytrace.f32a[7] = RenderPathRaytrace.help_mat.m[3];
		RenderPathRaytrace.f32a[8] = RenderPathRaytrace.help_mat.m[4];
		RenderPathRaytrace.f32a[9] = RenderPathRaytrace.help_mat.m[5];
		RenderPathRaytrace.f32a[10] = RenderPathRaytrace.help_mat.m[6];
		RenderPathRaytrace.f32a[11] = RenderPathRaytrace.help_mat.m[7];
		RenderPathRaytrace.f32a[12] = RenderPathRaytrace.help_mat.m[8];
		RenderPathRaytrace.f32a[13] = RenderPathRaytrace.help_mat.m[9];
		RenderPathRaytrace.f32a[14] = RenderPathRaytrace.help_mat.m[10];
		RenderPathRaytrace.f32a[15] = RenderPathRaytrace.help_mat.m[11];
		RenderPathRaytrace.f32a[16] = RenderPathRaytrace.help_mat.m[12];
		RenderPathRaytrace.f32a[17] = RenderPathRaytrace.help_mat.m[13];
		RenderPathRaytrace.f32a[18] = RenderPathRaytrace.help_mat.m[14];
		RenderPathRaytrace.f32a[19] = RenderPathRaytrace.help_mat.m[15];
		RenderPathRaytrace.f32a[20] = scene_world.strength * 1.5;
		if (!Context.raw.show_envmap) RenderPathRaytrace.f32a[20] = -RenderPathRaytrace.f32a[20];
		RenderPathRaytrace.f32a[21] = Context.raw.envmap_angle;
		RenderPathRaytrace.f32a[22] = RenderPathRaytrace.uv_scale;
		///if is_lab
		RenderPathRaytrace.f32a[22] *= scene_meshes[0].data.scale_tex;
		///end

		let framebuffer: image_t = render_path_render_targets.get("buf")._image;
		krom_raytrace_dispatch_rays(framebuffer.render_target_, RenderPathRaytrace.f32a.buffer);

		if (Context.raw.ddirty == 1 || Context.raw.pdirty == 1) {
			///if krom_metal
			Context.raw.rdirty = 128;
			///else
			Context.raw.rdirty = 4;
			///end
		}
		Context.raw.ddirty--;
		Context.raw.pdirty--;
		Context.raw.rdirty--;

		// Context.raw.ddirty = 1; // _RENDER
	}

	static raytrace_init = (shaderName: string, build: bool = true) => {
		if (RenderPathRaytrace.first) {
			RenderPathRaytrace.first = false;
			scene_embed_data("bnoise_sobol.k");
			scene_embed_data("bnoise_scramble.k");
			scene_embed_data("bnoise_rank.k");
		}

		let shader: ArrayBuffer = data_get_blob(shaderName);
		if (build) RenderPathRaytrace.build_data();
		krom_raytrace_init(shader, RenderPathRaytrace.vb.buffer_, RenderPathRaytrace.ib.buffer_, RenderPathRaytrace.vb_scale);
	}

	static build_data = () => {
		if (Context.raw.merged_object == null) UtilMesh.merge_mesh();
		///if is_paint
		let mo: mesh_object_t = !Context.layer_filter_used() ? Context.raw.merged_object : Context.raw.paint_object;
		///else
		let mo: mesh_object_t = scene_meshes[0];
		///end
		let md: mesh_data_t = mo.data;
		let mo_scale: f32 = mo.base.transform.scale.x; // Uniform scale only
		RenderPathRaytrace.vb_scale = md.scale_pos * mo_scale;
		if (mo.base.parent != null) RenderPathRaytrace.vb_scale *= mo.base.parent.transform.scale.x;
		RenderPathRaytrace.vb = md._.vertex_buffer;
		RenderPathRaytrace.ib = md._.index_buffers[0];
	}

	static draw = (useLiveLayer: bool) => {
		let isLive: bool = Config.raw.brush_live && RenderPathPaint.liveLayerDrawn > 0;
		if (Context.raw.ddirty > 1 || Context.raw.pdirty > 0 || isLive) RenderPathRaytrace.frame = 0;

		///if krom_metal
		// Delay path tracing additional samples while painting
		let down: bool = mouse_down() || pen_down();
		if (Context.in_viewport() && down) RenderPathRaytrace.frame = 0;
		///end

		RenderPathRaytrace.commands(useLiveLayer);

		if (Config.raw.rp_bloom != false) {
			RenderPathBase.draw_bloom("buf");
		}
		render_path_set_target("buf");
		render_path_draw_meshes("overlay");
		render_path_set_target("buf");
		RenderPathBase.draw_compass();
		render_path_set_target("taa");
		render_path_bind_target("buf", "tex");
		render_path_draw_shader("shader_datas/compositor_pass/compositor_pass");
		render_path_set_target("");
		render_path_bind_target("taa", "tex");
		render_path_draw_shader("shader_datas/copy_pass/copy_pass");
		if (Config.raw.brush_3d) {
			RenderPathPaint.commands_cursor();
		}
	}
}

///end
