//precision highp float;
out vec3 pos;
out vec3 worldPos;
vec4 lovrmain() {
  // Get the camera positon as a vec3 by taking the negative of the translation component and transforming it using the rotation component
  pos = -View[3].xyz * mat3(View);
  
  worldPos = (Transform * VertexPosition).xyz;

  return DefaultPosition;
}
