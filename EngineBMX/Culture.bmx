SuperStrict

Import "RaptorEngine.bmx"

Print "Creating core..."
RCore.DontPackage = False
RCore.CreateInstance()
Print "Created Instance."

Print "Getting core Instance..."
Local lCore:RCore = RCore.Instance()
Print "Got."

Print "Creating user display..."
lCore.CreateDisplay(800, 600, True)
Print "Created user display."


Local fileSys:RFileSystem = RFileSystem.Instance()

' Local c1:RContent = fileSys.GetContent("system/content/avatar/sentrybot/craft1.png")

Local tstMap:RMap2D = RMap2D.FromContent(fileSys.GetContent("system/content/map/desert_stage1.xml"))

Local l1:RLight2D = New RLight2D

l1.X = 300
l1.Y = 300
l1.Z = 5
l1.Range = 800;
l1.R = 1;
l1.G = 1
l1.B = 1

l1.Activate()

Local diffuseLit:FX_DiffuseLit = FX_DiffuseLit.Cr()


'Local t1:RTexture2D = RTexture2D.FromContent(c1)

Repeat
	PollEvent()
	Cls
	
	SetColor 255, 255, 255
	
	tstMap.Draw()

	Flip


Until KeyDown(KEY_ESCAPE)



