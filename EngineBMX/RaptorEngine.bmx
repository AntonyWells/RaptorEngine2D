SuperStrict
Import bah.libxml


Type RLog Extends RInstance

	Global _NAME:String = "Logger"
	Global _TYPE:String = "RLog"
	
	Method New()
	
		IName = _NAME
		IType = _TYPE
	
	End Method
	
	Function CreateInstance()
	
		RegisterInstance( New RLog )
	
	End Function

	Function Instance:RLog()
	
		Return RLog(RInstance.GetInstance(_Name,_Type))
			
	End Function

	Method Error(err:String,locale:String)
	
		Print "Err:"+err+"~nLocation:"+locale
		throw "Err:"+err+"~nLocation:"+locale
	
	End Method

End Type

Type RInstance

	Global InstanceMap:TMap = CreateMap()

	Field IName:String 
	Field IType:String 
	Field IAuthor:String
	Field ICopy:String 

	Function GetInstance:RInstance( c:String,t:String = "" )

		Try	
		Local i:RInstance = RInstance(MapValueForKey( InstanceMap,c ))
		
		If i <> Null
		
			If t<>""
			
				If i.IType <> t
				
					RLog.Instance().Error("Found instance with matching name, but of different type. Expected:"+t+" got:"+i.IType+" for:"+i.IName,"RInstance.GetInstance")
				
				EndIf
			
			EndIf
		
			Return i
		
		EndIf
		Catch err:String
		
			Print "Failed to get instance."
			RuntimeError "Instance faliure."
		
		End Try
	
	End Function

	Function RegisterInstance( i:RInstance )
	
		If MapContains( InstanceMap,i )
			
			RLog.Instance().Error( "Instance:"+i.IName+" of type:"+i.IType+" already registered as instance.","RInstance.RegisterInstance" )
					
		End If
	
		MapInsert( InstanceMap,i.IName,i )
	
	End Function

End Type

Type RCore Extends RInstance
	
	Const _NAME:String = "RaptorCore"
	Const _TYPE:String = "RCore"
	
	Field UserWidth:Float
	Field UserHeight:Float
	
	Global DontPackage:Int = False 
		
	Method New()
	
		IName = _NAME
		IType = _TYPE
		RLog.CreateInstance()
			
	End Method
	
	Function CreateInstance()
	
		RegisterInstance( New RCore )
			
	End Function

	Function Instance:RCore()
	
		Return RCore(RInstance.GetInstance(_NAME,_TYPE))
	
	End Function

	Method Create()
	
		UserWidth = -1
		UserHeight = -1
	
	End Method
	
	Method CreateDisplay(w:Int,h:Int,windowed:Int)
	
		UserWidth = w
		UserHeight = h
		
		SetGraphicsDriver GLMax2DDriver()
		Graphics w,h,32*(1-windowed)
		glewInit()
		RContentPackage.SetupContentSystem()
		RFileSystem.CreateInstance()
			
	End Method

End Type

Type RFileSystem Extends RInstance

	Const _NAME:String = "FileSystem"
	Const _TYPE:String = "RFileSystem"
	Field Content:TMap = CreateMap()
	 
	Method New()
	
		IName = _NAME
		IType = _TYPE
	
	
	End Method
	
	Method RegisterContent( path:String )
	
		content.insert( StripAll(path).tolower()+"/",path )
	
	End Method 
	
	Method GetContent:RContent( path:String )
	
		path = Replace(path,"\","/")
		path = path.tolower()
		Local fi:Int = Instr(path,"/")
		Local lib:String = Mid(path,1,fi)
		
		If Not content.contains(lib)
		
			Print "Unknown resource:"+path
			RLog.Instance().Error("Content package:"+lib+" not found or registered.","RFileSystem.GetContent()")
		
		EndIf
		
		Local obj:Object = content.valueforkey(lib)
		
		Local pack:RContentPackage 
		
		
		
		If Not rcontentpackage(obj)<>Null
		
			Local libPath:String = Mid(path,1,fi-1)+".content"
		
			pack = RContentPackage.OpenPackage( libPath )
			
			content.remove(lib)
			content.insert(lib,pack)
		
		Else
		
			pack = RContentPackage(obj)
		
		EndIf
	
		
	'	For Local c:RContent = EachIn pack.root.content
		
	'		Print c.globalname +"=="+path
	'		If c.globalname = path
		
	'			Return c
		
	'		EndIf
		
	'	Next
	
		Local c:RContent = RContent(MapValueForKey(pack.root.content,path))
		
		If c = Null
		
			RLog.Instance().Error("Content package was found matching resource path, but no resource within it matched the global path.:"+path,"RFileSystem.GetContent()")
		
		End If
		
		Return c
	
	End Method
	
	Function Instance:RFileSystem()
	
		Return RFileSystem(RInstance.GetInstance( _NAME,_TYPE))
	
	End Function
	
	Function CreateInstance()
		
		Print "Registering instance..."
		RInstance.RegisterInstance( New RFileSystem )
		Local fs:RFileSystem = Instance()
		Print "Done."

?debug
		Print "About to package content..."
		If Not RCore.DontPackage
		fs.PackageContent()
		EndIf
		Print "Done."
?
		Print "About to scan for packages..."
		fs.FindPackages()
		Print "Done."
	
	End Function
	
	Method PackageContent()
		
		RContentPackage.Package("system/")
		
	
	End Method
	
	Method FindPackages()

		Local dir:Int = ReadDir(CurrentDir())
		
		While True
		
			Local file:String = NextFile(dir)
			
			Select file
			
				Case ""
					Exit
				Case ".","..",".\","./","../","..\","	"," "
				Default
				
					If ExtractExt(file).tolower() = "content"
					
						RegisterContent( file )
					
					EndIf
			
			End Select
		
		Wend
		
		CloseDir dir
	
	End Method
	
End Type

Type RContent

	Field LocalName:String
	Field GlobalName:String
	Field OriginalRelativePath:String
	Field ContentStartByte:Long
	Field ContentLength:Long
	Field Content:TMap = CreateMap()
	Field ArcOffset:Long = 0
	Field Data:TBank
	Field Pack:RContentPackage
	Field DataStream:TStream 
	Field InMem:Int 
	
	Method ToStream:TStream()
	
		LoadIfNeed()
		DataStream.Seek(0)
		Return DataStream
	
	End Method
	
	Method ToBytePtr:Byte Ptr()
	
		LoadIfNeed()
		Return BankBuf(data)
	
	End Method
	
		
	Method LoadIfNeed()
	
		If InMem Return
		pack._FS.Seek( pack._OS + ContentStartByte )
		data = CreateBank(ContentLength)
		ReadBank(data, pack._FS,0,ContentLength )
		DataStream = CreateRamStream( BankBuf(data),ContentLength,True,False )
		InMem = True
			
	End Method
	
	Method AddContent( name:String,c:RContent )
		If c = Null
			Return
		EndIf
		If content.contains(name)
		
			Print "Filesystem error."
			RuntimeError "Content double entry for:"+c.LocalName+"("+c.GlobalName+")of="+c.originalrelativepath
		
		EndIf
		MapInsert(content,name,c)
	
	End Method

End Type



Type RContentPackage

	Field Path:String
	Field Root:RContent
	Field IgnoreFilter:TList = CreateList()
	Field _FS:TStream
	Field _OS:Int 

	Function SetupContentSystem()
	
	End Function


	Function OpenPackage:RContentPackage(path:String)
	
		Local _FS:TStream = ReadFile(path)
		
		If _fs = Null
		
			RLog.Instance().Error("Could not load content package:"+path,"RContentPackage.OpenPackage()")
					
		EndIf
		
		Local ret:RContentPackage = New RContentPackage
		Local root:RContent = New RContent
		root.pack = ret
		ret.root = root
		ret._FS = _fs
		While StreamPos(_FS)<StreamSize(_FS)
		
			Local op:Int = ReadByte(_FS)
			
			Select op
			
				Case 96
		
					Local nc:RContent = New RContent
					nc.LocalName = _FS.ReadLine()
					nc.globalname = _FS.ReadLine()
					nc.originalrelativepath = _FS.ReadLine()
					nc.contentstartbyte = _fs.ReadLong()
					nc.contentlength = _Fs.ReadLong()
					nc.pack = ret
					root.addcontent( nc.globalname.tolower(),nc )
					Print "Adding Content Header:~nLocal:"+nc.localName+"~nGlobal:"+nc.globalname			
				Case 128
				
					ret._OS = StreamPos(_FS)
					Exit 
			
			End Select
		
		
		Wend 
		
		Return ret
	
	
	End Function 
	
	Method Close()
	
		If _FS = Null
		
			RLog.Instance().Error("No active stream to close.","RContentPackage.Close()")
					
		End If
	
		_FS.Flush()
		_FS.Close()
		_FS = Null
	
	End Method

	Function Package:RContentPackage(path:String)
	
		Local r:RContentPackage = New RContentPackage
		
		r.Root = Null
		
		r.PackageFolder(path)
		r.SavePackage(ExtractDir(path))
		
		
		Return r
	
	End Function

	Method SavePackage(path:String)
		
		Print "Saving package..."
		
		If Right(path.tolower(),8)<>".content"
		
			path:+".content"
		
		EndIf
	
		Local fs:TStream = WriteFile(path)
		
		If fs = Null
		
			RuntimeError "Could not create content package:"+path
		
		EndIf
		
		Local tSiz:Long = 0 
		
		For Local key:String = EachIn MapKeys(root.content)
		
			Local c:RContent = RContent(root.content.valueforkey(key))
			
			tSiz:+BankSize(c.data)
		
		Next
		
		Local ram:Byte Ptr = MemAlloc(tSiz)
		
		Local rs:TRamStream = CreateRamStream(ram,tSiz,True,True)
		
		For Local key:String = EachIn MapKeys(root.content)
		
			Local c:RContent = RContent(root.content.valueforkey(key))
			
			WriteBank(c.data,rs,0,BankSize(c.data))
			
			fs.WriteByte(96)
			fs.WriteLine(c.localName)
			fs.WriteLine(c.globalname)
			fs.WriteLine(c.originalrelativepath)
			fs.WriteLong(rs.pos()-BankSize(c.data))
			fs.WriteLong(BankSize(c.data))
						
		Next
		
		fs.WriteByte(128)
		
		rs.seek(0)
		
		CopyStream(rs,fs)
		fs.flush()
		CloseFile fs
			
		Print "Saved."
	
	End Method

	Method PackageFolder:RContent(path:String)
	
		path = Replace(path,"\","/")
	
		Local r:RContent = New RContent		
		
		Local dir:Int = ReadDir(path)
		
		Local l:String = Chr(path[path.length-1])
		
		If Not (l="\" Or l="/")
				
			path=path+"/"
				
		EndIf
		
		r.LocalName = path
		r.GlobalName = path
		r.OriginalRelativePath = path
		
		Print "Packaging:"+path+" folder."
		
		If root = Null
		
			Root = r
			Print "!!Is package root."
		
		EndIf
		
		While True
		
			Local file:String = NextFile(dir)
			
			Select file
			
				Case ""
					Exit
				Case "./",".\","..",".","..\","../","`","	"," "
				Default
				
					Local fullPath:String = path + file
				
					Local ft:Int = FileType( fullPath )
					
					Select ft
					
						Case 1
						
							root.AddContent( fullPath,PackageFile( fullPath ) )
						
						Case 2
						
							PackageFolder( fullPath ) 
							
						Default
						
							
							If file.tolower().contains("ds_store")
								Continue
							EndIf
							
							
							Print "Filesystem error."
							RuntimeError "Unknown type of content:"+fullPath+" can not continue packaging file system."
							End
							
					End Select
			
			End Select
					
		Wend
		
		CloseDir dir
		
		Return r
	
	End Method

	Method PackageFile:RContent(path:String)
	
		
		Local r:RContent = New RContent
		r.LocalName = StripAll(path).tolower()
		If r.localname.length=0
			Return Null
		EndIf
	
		r.GlobalName = path.tolower()
		r.OriginalRelativePath = StripAll(path)+"."+ExtractExt(path)
		
	
		Local siz:Long = FileSize(path)
	
		Local fs:TStream = ReadFile(path)
		
		r.data = CreateBank(siz)	
	
		ReadBank(r.data,fs,0,siz)
		
		r.ContentStartByte = Root.ArcOffset
		r.ContentLength = siz
		Root.ArcOffset:+siz
	
		Print "Packaging file:"+r.localname
		
		CloseFile fs
		
		Return r
		
	End Method
	

End Type

Type RTexture Extends RInstance 

	Field Handle:Int 
	Field Width:Int,Height:Int
	Field Depth:Int
	Field BytesPerPixel:Int 
	Field Name:String
	Field Content:RContent 'if loaded via a package.
	
	Rem
		Returns texture from a given content path. do not use direct paths or direct streams, use the provided methods.
	End Rem
'	Function GetTexture:RTexture(path:String)
	
'		Local c:RContent = RFileSystem.Instance().GetContent(path)
'		Return RTexture.FromContent(c)
		
'	End Function
	
'	Method FromContent:RTexture()
	
'		RLog.Instance().Error("This paticular texture class has yet to extend the FromContent method, therefore can not construct it's self from a given content header.","RTexture.FromPixmap()")
'			
'	End Method
	
	Method Bind(unit:Int)
		
	End Method

	Method Unbind(unit:Int)
		
	End Method
	
End Type

Type RTexture2D Extends RTexture

	Field Pixels:TPixmap

	Function FromContent:RTexture2D(c:RContent)
	
		Return RTexture2D.FromPixmap(LoadPixmap(c.toStream()))	
	
	End Function 
	
	Method Bind(unit:Int)
	
		
		glClientActiveTexture(GL_TEXTURE0 + unit)
		glActiveTexture(GL_TEXTURE0 + unit)
		glEnable(GL_TEXTURE_2D)
		glBindTexture(GL_TEXTURE_2D, Handle)
	
	End Method
	
	Method Unbind(unit:Int)
		
		glClientActiveTexture(GL_TEXTURE0 + unit)
		glActiveTexture(GL_TEXTURE0 + unit) ;
		glBindTexture(GL_TEXTURE_2D, 0)
		glDisable(GL_TEXTURE_2D)
	
	End Method
	
	Function FromPixmap:RTexture2D(pix:TPixmap)
	
		Local r:RTexture2D = New RTexture2D
		
		r.pixels = pix
		
		r.width = PixmapWidth(pix)
		
		r.height = PixmapHeight(pix)
		
		glGenTextures(1, Varptr r.Handle)
				
		r.Bind(0)
		
		If PixmapFormat(pix) <> PF_RGBA8888
		
			r.Pixels = ConvertPixmap(pix, PF_RGBA8888)
			pix = r.Pixels
		
		End If
		
		r.UploadBuffer( pix.pixelptr(0,0) )
		
		r.Unbind(0)
		
		Return r
	
	End Function
	
	Method UploadBuffer( buf:Byte Ptr )
	
		glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE) ;
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST) ;
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR) ;
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT) ;
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT) ;
		gluBuild2DMipmaps(GL_TEXTURE_2D, GL_RGBA, Width, Height, GL_RGBA, GL_UNSIGNED_BYTE, buf)
		
	End Method
	
	
End Type

Type RTile

	Field Index:Int
	Field Set:RTileSet
	Field IsCollider:Int
	Field CastShadow:Int
	Field RecvShadow:Int
	Field IsRayTraced:Int
	
	Function FromSet:RTile(set:RTileSet, index:Int)
	
		Local r:RTile = New RTile
		
		r.index = index
		r.set = set
		r.RecvShadow = True
		r.IsRayTraced = True
		
		Return r
	
	End Function
	
End Type


Type RTileSet
	
	Field Visual:RTexture2D
	Field CellW:Int, CellH:Int
	Field firstgid:Int
	
	Function FromContent:RTileSet(c:RContent, cellw:Int, cellh:Int)
		
		Local r:RTileSet = New RTileSet;
		
		r.Visual = RTexture2D.FromContent(c) ;
		
		r.cellw = cellw
		r.cellh = cellh
					
		Return r
	
	End Function

End Type


Type RMap2D
	
	Field Tile:RTile[,,]
	Field MapW:Int, MapH:Int
	Field TileW:Int, TileH:Int
	Field Sets:TList = CreateList()
	Field SetMap:TMap = CreateMap()
	Field ViewX:Float, ViewY:Float, ViewZ:Float = 1
	Field ViewAng:Float
	Field Lights:TList = CreateList()
	
	Method AddLight(l:RLight2D)
		
		Lights.AddLast(l)
	
	End Method
	
	Function FromContent:RMap2D(c:RContent)
		
		Local fs:TStream = c.ToStream()
		Local ts:TStream = WriteFile("tmpMap.xml")
		CopyStream(fs, ts)
		CloseFile ts
		Local doc:TxmlDoc = TxmlDoc.parseFile("tmpMap.xml")
		Local map:TxmlNode = doc.getRootElement() ;
		
		
		Return RMap2D.FromXML(map)
	
	End Function
	
	Function FromXML:RMap2D(map:TxmlNode)
	
		Local r:RMap2D = New RMap2D
		
		r.LoadXML(map)
		
		Return r
	
	End Function

	Method LoadXML(n:TxmlNode)
		
		MapW = Int(n.getAttribute("width"))
		MapH = Int(n.getAttribute("height"))
		TileW = Int(n.getAttribute("tilewidth"))
		TileH = Int(n.getAttribute("tileheight"))
		
		If TileW < 2 Or TileH < 2 Or MapW < 1 Or MapH < 1
			
		
			RLog.Instance().Error("Map has unusual dimensions: mw:" + MapW + " mh:" + MapH + " tw:" + TileW + " th:" + TileH, "RMap2D.FromXML()") ;
			
		
		End If
		
		Local recvShad:Int = False
		Local castShad:Int = False
		Local isCollide:Int = False
		Local mx:Int, my:Int, mz:Int
		
		mx = 0
		my = 0
		mz = 0
		
		
		Tile = New RTile[MapW, MapH, 4] ;
		
		If n.getChildren() = Null Return
		
		For Local sn:TxmlNode = EachIn n.getChildren()
			
		
			Local op:String = sn.getName() ;
			
			Select op.ToLower()
				
				Case "layer"
				
					For Local ln:TxmlNode = EachIn sn.getChildren()
						
						Select ln.getName().ToLower()
							Case "data"
								
								mx = 0
								my = 0
											
								For Local tn:TxmlNode = EachIn ln.getChildren()
									
									Local gid:Int = Int(tn.getAttribute("gid"))
									
									Local lst:RTileSet
									
									For Local ts:RTileSet = EachIn Sets
										
										If ts.firstgid > gid
											
											Exit
										
										End If
										
										lst = ts
													
									Next
								
									If lst = Null And gid <> 0
									
										RLog.Instance().Error("No tileset found for gid:" + gid, "RMap2D.FromXML()")
									
									End If
									
									If gid = 0
										
										mx:+1
									If mx >= MapW
										mx = 0
										my:+1
										If my >= MapH
										
											my = 0
											mz:+1
													
										End If
									End If
									
										Continue
									
									End If
									
									Local nt:RTile = RTile.FromSet(lst, gid - lst.firstgid)
									
									Tile[mx, my, mz] = nt
									mx:+1
									If mx >= MapW
										mx = 0
										my:+1
										If my >= MapH
										
											my = 0
											mz:+1
													
										End If
									End If
									
								Next
							
							Case "properties"
							
								For Local pn:TxmlNode = EachIn ln.getChildren()
									
									If pn.getName().ToLower() <> "property"
										
										RLog.Instance().Error("Malformed property value.", "RMap2D.FromXML()")
										
									End If
								
									Select pn.getAttribute("name")
										Case "RecvShadow"
										
											recvShad = Int(pn.getAttribute("value"))
											Print "RecvShadow to true."
										Case "IsCollider"
										
											isCollide = Int(pn.getAttribute("value"))
											Print "Collide to true."
										Case "CastShadow"
										
											castShad = Int(pn.getAttribute("value"))
											Print "Shadow to true."
											
									End Select
									
								Next
							
							
						End Select
					
					Next
				
				Case "tileset"
				
					Local gid:Int = Int(sn.getAttribute("firstgid"))
					Local name:String = sn.getAttribute("name")
					Local src:String = TxmlNode(sn.getChildren().ValueAtIndex(0)).getAttribute("source")
					
					Local rpath:String = "system/content/tile/" + src
					
					Local ts:RTileSet = RTileSEt.FromContent(RFileSystem.Instance().GetContent(rpath), Int(sn.getAttribute("tilewidth")), Int(sn.getAttribute("tileheight")))
					
					ts.firstgid = gid
					
					Sets.AddLast(ts)
					SetMap.Insert(name, ts)
					
					If ts.CellW < 2 Or ts.CellH < 2
					
						RLog.Instance().Error("Tileset has unusual dimensions.", "RMap2D.FromXML()")
					
					End If
					
					
					
			End Select
			
		Next
			
		fx_difLit = FX_DiffuseLit.cr()
		
	End Method
	
	Field fx_difLit:FX_DiffuseLit
	
	Method Draw()
		
		Local mx:Int = GraphicsWidth() / 2
		Local my:Int = GraphicsHeight() / 2
		
		glEnable(GL_BLEND)
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		glColor4f(1, 1, 1, 1)
	
		fx_difLit.Use()
		
		For Local y:Int = 0 Until MapH
			
			Local dy:Float = (y * tileH * viewZ) - ViewY
			
			If dy < - TileH * 2 Continue
			If dy > GraphicsHeight() + TileH * 2 Continue
			
			For Local x:Int = 0 Until MapW
			
				Local dx:Float = (x * tilew * viewZ) - ViewX
				If dx < - TileW * 2 Continue
				If dy > GraphicsWidth() + TileW * 2 Continue
				
				Local vx:Float[4] ;
				Local vy:Float[4] ;
			
			
			vx[0] = dx;
			vy[0] = dy;
			
			vx[1] = dx + TileW * ViewZ;
			vy[1] = dy;
			
			vx[2] = vx[1];
			vy[2] = dy + TileH * ViewZ;
			
			vx[3] = dx;
			vy[3] = vy[2];
			
			For Local i:Int = 0 Until 4
				qr(vx[i], vy[i], Self.ViewAng, ViewZ, mx, my) ;
			Next
			
			
			
			
			For Local dz:Int = 0 Until 4
			
				Local t:RTile = Tile[x, y, dz]
				
				If t <> Null
				
				Local vu:Float[4], vv:Float[4]
				
				Local iw:Int = t.Set.Visual.Width
				Local ih:Int = t.Set.Visual.Height
				Local uid:Int = t.Index
				
	If(uid > 0)
		
		Local cx:Int, cy:Int;
	
		cx = iw / t.Set.CellW
		
		cy = ih / t.Set.CellH
		
	
		Local ax:Float, ay:Float;
	
		ay = Int(uid / cx)
		ax = Int(uid - (ay * cx)) ;

'		Notify "AX:" + ax + " AY:" + ay
		
		ax = ax * t.Set.CellW
		
		ay = ay * t.Set.CellH

		
		Local ax2:Float = (ax + t.Set.CellW) / Float(iw)
		Local ay2:Float = (ay + t.Set.CellH) / Float(ih)
			
		ax = ax / iw
		ay = ay / ih
		
		
		vu[0] = ax;
		vu[1] = ax2
		vu[2] = vu[1] ;
		vu[3] = vu[0]
		
		vv[0] = ay
		vv[1] = vv[0] ;
		vv[2] = ay2 ' -MouseY() * 0.0001 ;
		vv[3] = vv[2] ;
		
	
		
	endif

					
				t.Set.Visual.Bind(0)
				
				If Lights.Count() = 0
						
					glBegin(GL_QUADS)
						
					
						glTexCoord2f vu[0], vv[0]
						glVertex2f vx[0], vy[0]
						glTexCoord2f vu[1], vv[1]
						glVertex2f vx[1], vy[1]
						glTexCoord2f vu[2], vv[2]
						glVertex2f vx[2], vy[2]
						glTexCoord2f vu[3], vv[3]
						glVertex2f vx[3], vy[3]
											
					glEnd()
						
				Else
			
					For Local l:RLight2D = EachIn Lights
					
				
						l.Activate() ;
						
						Local ox:Float, oy:Float, oz:Float
						
						ox = l.x
						oy = l.y
						oz = l.Z
						
						l.x:*ViewZ
						l.y:*ViewZ
						
						qr(l.x, l.y, ViewAng, ViewZ, mx, my)
						l.Z = l.Z * ViewZ
						
						fx_difLit.UseLight = l
						
						fx_difLit.BindPar()
				
						l.x = ox
						l.y = oy
						l.Z = oz
						
						glBegin(GL_QUADS)
						
					
							glTexCoord2f vu[0], vv[0]
							glVertex2f vx[0], vy[0]
							glTexCoord2f vu[1], vv[1]
							glVertex2f vx[1], vy[1]
							glTexCoord2f vu[2], vv[2]
							glVertex2f vx[2], vy[2]
							glTexCoord2f vu[3], vv[3]
							glVertex2f vx[3], vy[3]
											
						glEnd()
					
					
				
					
					Next
			
				EndIf
				
				
				t.Set.Visual.Unbind(0)
			't.drawQuad(vx[0], vy[0], vx[1], vy[1], vx[2]:vy[2]:c:vx[3]:vy[3]:c:(0.2f + (z * 0.1f))] ;
				
				
				
				EndIf
				
			Next

			Next
	
		Next
		
		fx_difLit.fin()
	
	End Method
	
End Type


Type RShader

	Field Handle:Int
	Field Path:String
	
	Function FromContent:RShader(c:RContent)
	
		Local r:RShader = New RShader
		
		Local fs:TStream = c.ToStream() ;
		
		Local code:String
		
		While fs.Pos() < fs.Size()
			
			code:+fs.ReadLine() + "~n"
					
		WEnd
	
		Local typ:String = ExtractExt(c.GlobalName)
		Local st:Int
		Select typ.ToLower()
			Case "vert", "vertex", "v", "vs", "vsh"
				st = GL_VERTEX_SHADER_ARB
			Case "frag", "fragment", "pixel", "pix", "p", "ps", "psh"
				st = GL_FRAGMENT_SHADER_ARB
		End Select
		
		r.Handle = glCreateShaderObjectARB(st)
		
		Local cl:Int = code.Length
		Local bp:Byte Ptr = code.ToCString()
		Local b2:Byte Ptr Ptr = Varptr bp
		
		glShaderSourceARB(r.Handle, 1, b2, Varptr cl)
		
		glCompileShader(r.Handle)
		
		Local cstat:Int = False
		
		glGetObjectParameterivARB(r.Handle, GL_OBJECT_COMPILE_STATUS_ARB, Varptr cstat)
		
		Local logl:Int = 0
		
		glGetObjectParameterivARB(r.Handle, GL_OBJECT_INFO_LOG_LENGTH_ARB, Varptr logl) ;
		
		If logl > 0 
			
			Local al:Int = 0
			Local info:Byte Ptr = MemAlloc(1024 * 1024)
			glGetInfoLogARB(r.Handle, 1024 * 1024, Varptr al, info) ;
			RLog.Instance().Error("Shader Compile Error~nCode:"+code+"~nError:" + String.FromBytes(info, al), "RShader.FromContent()")
			
			
		End If
		
		
		Return r
	End Function

End Type

Type REffect
	
	Field VertShader:RShader
	Field FragShader:RShader
	
	Field Program:Int
	
	Method FromContent(vert:RContent, frag:RContent)
			

		If vert <> Null
		
			VertShader = RShader.FromContent(vert)
		
		EndIf
		
		If frag <> Null
	
			FragShader = RShader.FromContent(frag)
	
		EndIf

		Program = glCreateProgramObjectARB()
		
		If vert <> Null
		
			glAttachObjectARB(Program, VertShader.Handle)
		
		EndIf
		
		If frag <> Null
		
			glAttachObjectARB(Program, FragShader.Handle)
		
		EndIf
		
		glLinkProgramARB(Program)
		
			Local cstat:Int = False
		
		glGetObjectParameterivARB(Program, GL_OBJECT_COMPILE_STATUS_ARB, Varptr cstat)
		
		Local logl:Int = 0
		
		glGetObjectParameterivARB(Program, GL_OBJECT_INFO_LOG_LENGTH_ARB, Varptr logl) ;
		
		If logl > 0
			
			Local al:Int = 0
			Local info:Byte Ptr = MemAlloc(1024 * 1024)
			glGetInfoLogARB(Program, 1024 * 1024, Varptr al, info) ;
			RLog.Instance().Error("Program Linking Error~nError:" + String.FromBytes(info, al), "REffect.FromContent()")
			
			
		End If
				

	End Method

	Method Use()
		
		glUseProgramObjectARB(Program)
	
	End Method
	
	Method fin()
		
		glUseProgramObjectARB(0)
	
	End Method
	
	Method BindPar()
		
	
	End Method
	
	Method Loc:Int(n:String)
		
		Return glGetUniformLocationARB(Program, n.ToCString())
	
	End Method
	
	Method V3(loc:Int, x:Float, y:Float, z:Float)
		
		glUniform3f(loc, x, y, z)
	
	End Method
	
	Method F(loc:Int, v:Float)
	
		glUniform1f(loc, v)
	
	End Method
	
	Method V2(loc:Int, x:Float, y:Float)
	
		glUniform2f(loc, x, y)
	
	End Method
	
	
End Type

Type RLight2D

	Field X:Float, Y:Float, Z:Float
	Field R:Float, G:Float, B:Float
	Field Range:Float
	Global Active:RLight2D
	Global Lights:TList = CreateList()
	
	Method New()
		
		
	
	End Method
	
	
	Method Activate()
	
		Active = Self
	
	End Method
End Type

Type FX_DiffuseLit Extends REffect

	Field UseLight:RLight2D
	Field lPos:Int, lCol:Int, lRange:Int
	Function Cr:FX_DiffuseLit()
	
			Local r:FX_DiffuseLit = New FX_DiffuseLit
			r.FromContent(RFileSystem.Instance().GetContent("system/content/effect/diffuseLit.vertex"), RFileSystem.Instance().GetContent("system/content/effect/diffuseLit.fragment"))
			r.lPos = r.Loc("LightPosition")
			r.lCol = r.Loc("LightColor")
			r.lRange = r.Loc("LightRange")
			Return r
	
	End Function
	
	Method Use()
		If UseLight = Null
			UseLight = RLight2D.Active
			If UseLight = Null
				RLog.Instance().Error("Can not use FX_DiffuseLit effect without assigning a light to it first.", "REffect.Use") ;
			EndIf
			
		End If
		BindPar()
		Super.Use()
		BindPar()
	End Method
	
	Method BindPar()
		
		V3(lPos, UseLight.X, UseLight.Y, UseLight.Z)
		F(lRange, UseLight.Range)
		V3(lCol, UseLight.r, UseLight.G, UseLight.B)
				
	End Method
	
	Method fin()
		Super.fin()
	End Method

End Type

Function qr(x:Float Var, y:Float Var, ang:Float, scal:Float, mx:Float, my:Float)
	
	Local nx:Float, ny:Float;
	nx = x - mx;
	ny = y - my;

	Local tx:Float, ty:Float;
	tx = Cos(ang) * nx + -Sin(ang) * ny ;
	ty = Sin(ang) * nx + Cos(ang) * ny ;
	x = mx + tx * scal;
	y = my + ty * scal;


End Function

'---------------