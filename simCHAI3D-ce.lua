local codeEditorInfos=[[
int objectID=simCHAI3D.addConstraintPlane(int deviceIndex,float[3] position,float[3] normal,float Kp,float Kv,float Fmax)
int objectID=simCHAI3D.addConstraintPoint(int deviceIndex,float[3] position,float Kp,float Kv,float Fmax)
int objectID=simCHAI3D.addConstraintSegment(int deviceIndex,float[3] point,float[3] segment,float Kp,float Kv,float Fmax)
int objectID=simCHAI3D.addShape(float[] vertices,int[] indices,float[3] position,float[3] orientation,float stiffnessFactor)
int buttons=simCHAI3D.readButtons(int deviceIndex)
float[3] force=simCHAI3D.readForce(int deviceIndex)
float[3] position=simCHAI3D.readPosition(int deviceIndex)
simCHAI3D.removeObject(int objectID)
simCHAI3D.reset()
int result=simCHAI3D.start(int deviceIndex,float toolRadius,float workspaceRadius)
simCHAI3D.updateConstraint(int objectID,float[3] positionA,float[3] positionB,float Kp,float Kv,float Fmax)
simCHAI3D.updateShape(int objectID,float[3] position,float[3] orientation,float stiffnessFactor)
]]

registerCodeEditorInfos("simCHAI3D",codeEditorInfos)
