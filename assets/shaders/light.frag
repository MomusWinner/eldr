#version 450

#include "gen_types.h"
#include "buildin:defines/helper.h"

layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec4 fragColor;
layout(location = 2) in vec3 fragNormal;
layout(location = 3) in vec3 fragPos;

layout(location = 0) out vec4 outColor;

void main() {
	vec3 normal = normalize(fragNormal);
	vec4 ambient = getLightMaterial().ambient * getLightMaterial().color;
	vec3 lightDir = normalize(-getLightMaterial().direction);
	float diff = max(dot(normal, lightDir), 0.0);
	vec4 diffuse = getLightMaterial().diffuse * diff * getLightMaterial().color;

	vec3 viewDir = normalize(getLightMaterial().view_pos - fragPos);
	vec3 reflectDir = reflect(-lightDir, normal);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), 10);
	// vec3 specular = spec;

	outColor = ambient + diffuse + getLightMaterial().diffuse * spec;
}
