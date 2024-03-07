
class UtilMesh {

	static unwrappers: Map<string, ((a: any)=>void)> = new Map();

	static merge_mesh = (paintObjects: mesh_object_t[] = null) => {
		if (paintObjects == null) paintObjects = Project.paint_objects;
		if (paintObjects.length == 0) return;
		Context.raw.merged_object_is_atlas = paintObjects.length < Project.paint_objects.length;
		let vlen: i32 = 0;
		let ilen: i32 = 0;
		let maxScale: f32 = 0.0;
		for (let i: i32 = 0; i < paintObjects.length; ++i) {
			vlen += paintObjects[i].data.vertex_arrays[0].values.length;
			ilen += paintObjects[i].data.index_arrays[0].values.length;
			if (paintObjects[i].data.scale_pos > maxScale) maxScale = paintObjects[i].data.scale_pos;
		}
		vlen = Math.floor(vlen / 4);
		let va0: Int16Array = new Int16Array(vlen * 4);
		let va1: Int16Array = new Int16Array(vlen * 2);
		let va2: Int16Array = new Int16Array(vlen * 2);
		let va3: Int16Array = paintObjects[0].data.vertex_arrays.length > 3 ? new Int16Array(vlen * 4) : null;
		let ia: Uint32Array = new Uint32Array(ilen);

		let voff: i32 = 0;
		let ioff: i32 = 0;
		for (let i: i32 = 0; i < paintObjects.length; ++i) {
			let vas: vertex_array_t[] = paintObjects[i].data.vertex_arrays;
			let ias: index_array_t[] = paintObjects[i].data.index_arrays;
			let scale: f32 = paintObjects[i].data.scale_pos;

			// Pos
			for (let j: i32 = 0; j < vas[0].values.length; ++j) va0[j + voff * 4] = vas[0].values[j];

			// Translate
			///if is_forge
			for (let j: i32 = 0; j < Math.floor(va0.length / 4); ++j) {
				va0[j * 4     + voff * 4] += Math.floor(transform_world_x(paintObjects[i].base.transform) * 32767);
				va0[j * 4 + 1 + voff * 4] += Math.floor(transform_world_y(paintObjects[i].base.transform) * 32767);
				va0[j * 4 + 2 + voff * 4] += Math.floor(transform_world_z(paintObjects[i].base.transform) * 32767);
			}
			///end

			// Re-scale
			for (let j: i32 = 0; j < Math.floor(va0.length / 4); ++j) {
				va0[j * 4     + voff * 4] = Math.floor((va0[j * 4     + voff * 4] * scale) / maxScale);
				va0[j * 4 + 1 + voff * 4] = Math.floor((va0[j * 4 + 1 + voff * 4] * scale) / maxScale);
				va0[j * 4 + 2 + voff * 4] = Math.floor((va0[j * 4 + 2 + voff * 4] * scale) / maxScale);
			}
			// Nor
			for (let j: i32 = 0; j < vas[1].values.length; ++j) va1[j + voff * 2] = vas[1].values[j];
			// Tex
			for (let j: i32 = 0; j < vas[2].values.length; ++j) va2[j + voff * 2] = vas[2].values[j];
			// Col
			if (va3 != null) for (let j: i32 = 0; j < vas[3].values.length; ++j) va3[j + voff * 4] = vas[3].values[j];
			// Indices
			for (let j: i32 = 0; j < ias[0].values.length; ++j) ia[j + ioff] = ias[0].values[j] + voff;

			voff += Math.floor(vas[0].values.length / 4);
			ioff += Math.floor(ias[0].values.length);
		}

		let raw: mesh_data_t = {
			name: Context.raw.paint_object.base.name,
			vertex_arrays: [
				{ values: va0, attrib: "pos", data: "short4norm" },
				{ values: va1, attrib: "nor", data: "short2norm" },
				{ values: va2, attrib: "tex", data: "short2norm" }
			],
			index_arrays: [
				{ values: ia, material: 0 }
			],
			scale_pos: maxScale,
			scale_tex: 1.0
		};
		if (va3 != null) raw.vertex_arrays.push({ values: va3, attrib: "col", data: "short4norm" });

		UtilMesh.remove_merged_mesh();
		let md: mesh_data_t = mesh_data_create(raw);
		Context.raw.merged_object = mesh_object_create(md, Context.raw.paint_object.materials);
		Context.raw.merged_object.base.name = Context.raw.paint_object.base.name + "_merged";
		Context.raw.merged_object.force_context = "paint";
		object_set_parent(Context.raw.merged_object.base, Context.main_object().base);

		///if (krom_direct3d12 || krom_vulkan || krom_metal)
		RenderPathRaytrace.ready = false;
		///end
	}

	static remove_merged_mesh = () => {
		if (Context.raw.merged_object != null) {
			mesh_data_delete(Context.raw.merged_object.data);
			mesh_object_remove(Context.raw.merged_object);
			Context.raw.merged_object = null;
		}
	}

	static swap_axis = (a: i32, b: i32) => {
		let objects: mesh_object_t[] = Project.paint_objects;
		for (let o of objects) {
			// Remapping vertices, buckle up
			// 0 - x, 1 - y, 2 - z
			let vas: vertex_array_t[] = o.data.vertex_arrays;
			let pa: i16_array_t  = vas[0].values;
			let na0: i16_array_t = a == 2 ? vas[0].values : vas[1].values;
			let na1: i16_array_t = b == 2 ? vas[0].values : vas[1].values;
			let c: i32 = a == 2 ? 3 : a;
			let d: i32 = b == 2 ? 3 : b;
			let e: i32 = a == 2 ? 4 : 2;
			let f: i32 = b == 2 ? 4 : 2;

			for (let i: i32 = 0; i < Math.floor(pa.length / 4); ++i) {
				let t: i32 = pa[i * 4 + a];
				pa[i * 4 + a] = pa[i * 4 + b];
				pa[i * 4 + b] = -t;
				t = na0[i * e + c];
				na0[i * e + c] = na1[i * f + d];
				na1[i * f + d] = -t;
			}

			let g: mesh_data_t = o.data;
			let l: i32 = g4_vertex_struct_byte_size(g._.structure) / 2;
			let vertices: buffer_view_t = g4_vertex_buffer_lock(g._.vertex_buffer); // posnortex
			for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 2 / l); ++i) {
				vertices.setInt16((i * l    ) * 2, vas[0].values[i * 4    ], true);
				vertices.setInt16((i * l + 1) * 2, vas[0].values[i * 4 + 1], true);
				vertices.setInt16((i * l + 2) * 2, vas[0].values[i * 4 + 2], true);
				vertices.setInt16((i * l + 3) * 2, vas[0].values[i * 4 + 3], true);
				vertices.setInt16((i * l + 4) * 2, vas[1].values[i * 2    ], true);
				vertices.setInt16((i * l + 5) * 2, vas[1].values[i * 2 + 1], true);
			}
			g4_vertex_buffer_unlock(g._.vertex_buffer);
		}

		UtilMesh.remove_merged_mesh();
		UtilMesh.merge_mesh();
	}

	static flip_normals = () => {
		let objects: mesh_object_t[] = Project.paint_objects;
		for (let o of objects) {
			let vas: vertex_array_t[] = o.data.vertex_arrays;
			let va0: i16_array_t = vas[0].values;
			let va1: i16_array_t = vas[1].values;
			let g: mesh_data_t = o.data;
			let l: i32 = g4_vertex_struct_byte_size(g._.structure) / 2;
			let vertices: buffer_view_t = g4_vertex_buffer_lock(g._.vertex_buffer); // posnortex
			for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 2 / l); ++i) {
				va0[i * 4 + 3] = -va0[i * 4 + 3];
				va1[i * 2] = -va1[i * 2];
				va1[i * 2 + 1] = -va1[i * 2 + 1];
				vertices.setInt16((i * l + 3) * 2, -vertices.getInt16((i * l + 3) * 2, true), true);
				vertices.setInt16((i * l + 4) * 2, -vertices.getInt16((i * l + 4) * 2, true), true);
				vertices.setInt16((i * l + 5) * 2, -vertices.getInt16((i * l + 5) * 2, true), true);
			}
			g4_vertex_buffer_unlock(g._.vertex_buffer);
		}

		///if (krom_direct3d12 || krom_vulkan || krom_metal)
		RenderPathRaytrace.ready = false;
		///end
	}

	static calc_normals = (smooth: bool = false) => {
		let va: vec4_t = vec4_create();
		let vb: vec4_t = vec4_create();
		let vc: vec4_t = vec4_create();
		let cb: vec4_t = vec4_create();
		let ab: vec4_t = vec4_create();
		let objects: mesh_object_t[] = Project.paint_objects;
		for (let o of objects) {
			let g: mesh_data_t = o.data;
			let l: i32 = g4_vertex_struct_byte_size(g._.structure) / 2;
			let inda: u32_array_t = g._.indices[0];
			let vertices: buffer_view_t = g4_vertex_buffer_lock(g._.vertex_buffer); // posnortex
			for (let i: i32 = 0; i < Math.floor(inda.length / 3); ++i) {
				let i1: i32 = inda[i * 3    ];
				let i2: i32 = inda[i * 3 + 1];
				let i3: i32 = inda[i * 3 + 2];
				vec4_set(va, vertices.getInt16((i1 * l) * 2, true), vertices.getInt16((i1 * l + 1) * 2, true), vertices.getInt16((i1 * l + 2) * 2, true));
				vec4_set(vb, vertices.getInt16((i2 * l) * 2, true), vertices.getInt16((i2 * l + 1) * 2, true), vertices.getInt16((i2 * l + 2) * 2, true));
				vec4_set(vc, vertices.getInt16((i3 * l) * 2, true), vertices.getInt16((i3 * l + 1) * 2, true), vertices.getInt16((i3 * l + 2) * 2, true));
				vec4_sub_vecs(cb, vc, vb);
				vec4_sub_vecs(ab, va, vb);
				vec4_cross(cb, ab);
				vec4_normalize(cb, );
				vertices.setInt16((i1 * l + 4) * 2, Math.floor(cb.x * 32767), true);
				vertices.setInt16((i1 * l + 5) * 2, Math.floor(cb.y * 32767), true);
				vertices.setInt16((i1 * l + 3) * 2, Math.floor(cb.z * 32767), true);
				vertices.setInt16((i2 * l + 4) * 2, Math.floor(cb.x * 32767), true);
				vertices.setInt16((i2 * l + 5) * 2, Math.floor(cb.y * 32767), true);
				vertices.setInt16((i2 * l + 3) * 2, Math.floor(cb.z * 32767), true);
				vertices.setInt16((i3 * l + 4) * 2, Math.floor(cb.x * 32767), true);
				vertices.setInt16((i3 * l + 5) * 2, Math.floor(cb.y * 32767), true);
				vertices.setInt16((i3 * l + 3) * 2, Math.floor(cb.z * 32767), true);
			}

			if (smooth) {
				let shared: Uint32Array = new Uint32Array(1024);
				let sharedLen: i32 = 0;
				let found: i32[] = [];
				for (let i: i32 = 0; i < (inda.length - 1); ++i) {
					if (found.indexOf(i) >= 0) continue;
					let i1: i32 = inda[i];
					sharedLen = 0;
					shared[sharedLen++] = i1;
					for (let j: i32 = (i + 1); j < inda.length; ++j) {
						let i2: i32 = inda[j];
						let i1l: i32 = i1 * l;
						let i2l: i32 = i2 * l;
						if (vertices.getInt16((i1l    ) * 2, true) == vertices.getInt16((i2l    ) * 2, true) &&
							vertices.getInt16((i1l + 1) * 2, true) == vertices.getInt16((i2l + 1) * 2, true) &&
							vertices.getInt16((i1l + 2) * 2, true) == vertices.getInt16((i2l + 2) * 2, true)) {
							// if (n1.dot(n2) > 0)
							shared[sharedLen++] = i2;
							found.push(j);
							if (sharedLen >= 1024) break;
						}
					}
					if (sharedLen > 1) {
						vec4_set(va, 0, 0, 0);
						for (let j: i32 = 0; j < sharedLen; ++j) {
							let i1: i32 = shared[j];
							let i1l: i32 = i1 * l;
							vec4_add_f(va, vertices.getInt16((i1l + 4) * 2, true), vertices.getInt16((i1l + 5) * 2, true), vertices.getInt16((i1l + 3) * 2, true));
						}
						vec4_mult(va, 1 / sharedLen);
						vec4_normalize(va, );
						let vax: i32 = Math.floor(va.x * 32767);
						let vay: i32 = Math.floor(va.y * 32767);
						let vaz: i32 = Math.floor(va.z * 32767);
						for (let j: i32 = 0; j < sharedLen; ++j) {
							let i1: i32 = shared[j];
							let i1l: i32 = i1 * l;
							vertices.setInt16((i1l + 4) * 2, vax, true);
							vertices.setInt16((i1l + 5) * 2, vay, true);
							vertices.setInt16((i1l + 3) * 2, vaz, true);
						}
					}
				}
			}
			g4_vertex_buffer_unlock(g._.vertex_buffer);

			let va0: i16_array_t = o.data.vertex_arrays[0].values;
			let va1: i16_array_t = o.data.vertex_arrays[1].values;
			for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 4 / l); ++i) {
				va1[i * 2    ] = vertices.getInt16((i * l + 4) * 2, true);
				va1[i * 2 + 1] = vertices.getInt16((i * l + 5) * 2, true);
				va0[i * 4 + 3] = vertices.getInt16((i * l + 3) * 2, true);
			}
		}

		///if (krom_direct3d12 || krom_vulkan || krom_metal)
		UtilMesh.merge_mesh();
		RenderPathRaytrace.ready = false;
		///end
	}

	static to_origin = () => {
		let dx: f32 = 0.0;
		let dy: f32 = 0.0;
		let dz: f32 = 0.0;
		for (let o of Project.paint_objects) {
			let l: i32 = 4;
			let sc: f32 = o.data.scale_pos / 32767;
			let va: i16_array_t = o.data.vertex_arrays[0].values;
			let minx: f32 = va[0];
			let maxx: f32 = va[0];
			let miny: f32 = va[1];
			let maxy: f32 = va[1];
			let minz: f32 = va[2];
			let maxz: f32 = va[2];
			for (let i: i32 = 1; i < Math.floor(va.length / l); ++i) {
				if (va[i * l] < minx) minx = va[i * l];
				else if (va[i * l] > maxx) maxx = va[i * l];
				if (va[i * l + 1] < miny) miny = va[i * l + 1];
				else if (va[i * l + 1] > maxy) maxy = va[i * l + 1];
				if (va[i * l + 2] < minz) minz = va[i * l + 2];
				else if (va[i * l + 2] > maxz) maxz = va[i * l + 2];
			}
			dx += (minx + maxx) / 2 * sc;
			dy += (miny + maxy) / 2 * sc;
			dz += (minz + maxz) / 2 * sc;
		}
		dx /= Project.paint_objects.length;
		dy /= Project.paint_objects.length;
		dz /= Project.paint_objects.length;

		for (let o of Project.paint_objects) {
			let g: mesh_data_t = o.data;
			let sc: f32 = o.data.scale_pos / 32767;
			let va: i16_array_t = o.data.vertex_arrays[0].values;
			let maxScale: f32 = 0.0;
			for (let i: i32 = 0; i < Math.floor(va.length / 4); ++i) {
				if (Math.abs(va[i * 4    ] * sc - dx) > maxScale) maxScale = Math.abs(va[i * 4    ] * sc - dx);
				if (Math.abs(va[i * 4 + 1] * sc - dy) > maxScale) maxScale = Math.abs(va[i * 4 + 1] * sc - dy);
				if (Math.abs(va[i * 4 + 2] * sc - dz) > maxScale) maxScale = Math.abs(va[i * 4 + 2] * sc - dz);
			}
			o.base.transform.scale_world = o.data.scale_pos = o.data.scale_pos = maxScale;
			transform_build_matrix(o.base.transform);

			for (let i: i32 = 0; i < Math.floor(va.length / 4); ++i) {
				va[i * 4    ] = Math.floor((va[i * 4    ] * sc - dx) / maxScale * 32767);
				va[i * 4 + 1] = Math.floor((va[i * 4 + 1] * sc - dy) / maxScale * 32767);
				va[i * 4 + 2] = Math.floor((va[i * 4 + 2] * sc - dz) / maxScale * 32767);
			}

			let l: i32 = g4_vertex_struct_byte_size(g._.structure) / 2;
			let vertices: buffer_view_t = g4_vertex_buffer_lock(g._.vertex_buffer); // posnortex
			for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 2 / l); ++i) {
				vertices.setInt16((i * l    ) * 2, va[i * 4    ], true);
				vertices.setInt16((i * l + 1) * 2, va[i * 4 + 1], true);
				vertices.setInt16((i * l + 2) * 2, va[i * 4 + 2], true);
			}
			g4_vertex_buffer_unlock(g._.vertex_buffer);
		}

		UtilMesh.merge_mesh();
	}

	static apply_displacement = (texpaint_pack: image_t, strength: f32 = 0.1, uvScale: f32 = 1.0) => {
		let height: buffer_t = image_get_pixels(texpaint_pack);
		let heightView: buffer_view_t = new DataView(height);
		let res: i32 = texpaint_pack.width;
		let o: mesh_object_t = Project.paint_objects[0];
		let g: mesh_data_t = o.data;
		let l: i32 = g4_vertex_struct_byte_size(g._.structure) / 2;
		let vertices: buffer_view_t = g4_vertex_buffer_lock(g._.vertex_buffer); // posnortex
		for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 2 / l); ++i) {
			let x: i32 = Math.floor(vertices.getInt16((i * l + 6) * 2, true) / 32767 * res);
			let y: i32 = Math.floor(vertices.getInt16((i * l + 7) * 2, true) / 32767 * res);
			let xx: i32 = Math.floor(x * uvScale) % res;
			let yy: i32 = Math.floor(y * uvScale) % res;
			let h: f32 = (1.0 - heightView.getUint8((yy * res + xx) * 4 + 3) / 255) * strength;
			vertices.setInt16((i * l    ) * 2, vertices.getInt16((i * l    ) * 2, true) - Math.floor(vertices.getInt16((i * l + 4) * 2, true) * h), true);
			vertices.setInt16((i * l + 1) * 2, vertices.getInt16((i * l + 1) * 2, true) - Math.floor(vertices.getInt16((i * l + 5) * 2, true) * h), true);
			vertices.setInt16((i * l + 2) * 2, vertices.getInt16((i * l + 2) * 2, true) - Math.floor(vertices.getInt16((i * l + 3) * 2, true) * h), true);
		}
		g4_vertex_buffer_unlock(g._.vertex_buffer);

		let va0: i16_array_t = o.data.vertex_arrays[0].values;
		for (let i: i32 = 0; i < Math.floor(vertices.byteLength / 4 / l); ++i) {
			va0[i * 4    ] = vertices.getInt16((i * l    ) * 2, true);
			va0[i * 4 + 1] = vertices.getInt16((i * l + 1) * 2, true);
			va0[i * 4 + 2] = vertices.getInt16((i * l + 2) * 2, true);
		}
	}

	static equirect_unwrap = (mesh: any) => {
		let verts: i32 = Math.floor(mesh.posa.length / 4);
		mesh.texa = new Int16Array(verts * 2);
		let n: vec4_t = vec4_create();
		for (let i: i32 = 0; i < verts; ++i) {
			vec4_normalize(vec4_set(n, mesh.posa[i * 4] / 32767, mesh.posa[i * 4 + 1] / 32767, mesh.posa[i * 4 + 2] / 32767));
			// Sphere projection
			// mesh.texa[i * 2    ] = Math.atan2(n.x, n.y) / (Math.PI * 2) + 0.5;
			// mesh.texa[i * 2 + 1] = n.z * 0.5 + 0.5;
			// Equirect
			mesh.texa[i * 2    ] = Math.floor(((Math.atan2(-n.z, n.x) + Math.PI) / (Math.PI * 2)) * 32767);
			mesh.texa[i * 2 + 1] = Math.floor((Math.acos(n.y) / Math.PI) * 32767);
		}
	}

	static pnpoly = (v0x: f32, v0y: f32, v1x: f32, v1y: f32, v2x: f32, v2y: f32, px: f32, py: f32): bool => {
		// https://wrf.ecse.rpi.edu//Research/Short_Notes/pnpoly.html
		let c: bool = false;
		if (((v0y > py) != (v2y > py)) && (px < (v2x - v0x) * (py - v0y) / (v2y - v0y) + v0x)) c = !c;
		if (((v1y > py) != (v0y > py)) && (px < (v0x - v1x) * (py - v1y) / (v0y - v1y) + v1x)) c = !c;
		if (((v2y > py) != (v1y > py)) && (px < (v1x - v2x) * (py - v2y) / (v1y - v2y) + v2x)) c = !c;
		return c;
	}

	static calc_normal = (p0: vec4_t, p1: vec4_t, p2: vec4_t): vec4_t => {
		let cb: vec4_t = vec4_sub_vecs(vec4_create(), p2, p1);
		let ab: vec4_t = vec4_sub_vecs(vec4_create(), p0, p1);
		vec4_cross(cb, ab);
		vec4_normalize(cb);
		return cb;
	}
}
