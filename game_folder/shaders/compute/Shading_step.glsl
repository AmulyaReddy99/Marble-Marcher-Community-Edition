#version 430
//4*4 ray bundle
#define group_size 8
#define block_size 64

layout(local_size_x = group_size, local_size_y = group_size) in;
layout(rgba32f, binding = 0) uniform image2D illumination; //calculate final color
layout(rgba8, binding = 1) uniform image2D color_output; //calculate final color
layout(rgba32f, binding = 2) uniform image2D DE_input; 
layout(rgba32f, binding = 3) uniform image2D color_HDR; //calculate final color


//make all the local distance estimator spheres shared
shared vec4 de_sph[group_size][group_size]; 

#include<camera.glsl>
#include<shading.glsl>

#define VIGNETTE_STRENGTH 0.2


void main() {
	ivec2 global_pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 local_indx = ivec2(gl_LocalInvocationID.xy);
	vec2 img_size = vec2(imageSize(color_output));
	
	vec4 sph = imageLoad(DE_input, global_pos);
	vec4 illum = interp(illumination, vec2(global_pos)*0.5f);
	
	ray rr = get_ray(vec2(global_pos)/img_size);
	vec4 pos = vec4(rr.pos,0);
	vec4 dir = vec4(rr.dir,0);
	vec4 var = vec4(0);
	
	float td = dot(dir.xyz, sph.xyz - pos.xyz);//traveled distance
	
	pos = sph;
	dir.w += td; 
	
	vec4 color;
	if(pos.w < max(2*fovray*td, MIN_DIST) )
	{
		color = shading(pos, dir, fovray, illum.x);
	}
	else
	{
		vec3 sky = sky_color(dir.xyz);
		color = vec4(sky*sky,0);
	}
	
	vec4 prev_color = imageLoad(color_HDR, global_pos);
	if(!isnan(color.x) && !isnan(color.y) && !isnan(color.z))
	{
		color = prev_color*Camera.mblur + (1-Camera.mblur)*color; //blur
		float vignette = 1.0 - VIGNETTE_STRENGTH * length(vec2(global_pos)/img_size - 0.5);
		imageStore(color_HDR, global_pos, vec4(color.xyz, 1));	 
		imageStore(color_output, global_pos,  vec4(HDRmapping(color.xyz, Camera.exposure, 2.2)*vignette, 1));	  	
	}
}