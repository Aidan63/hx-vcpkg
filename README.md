# Hx-Vcpkg

Integrate vcpkg into haxe and eases linking into the hxcpp build system.

## Installing Libraries

Requiring libraries be built as part of building a haxe project is as simple as adding a macro call to the hxml file. Add a `hxvcpkg.Vcpkg.install` call for each port you want to install.

```hxml
--macro hxvcpkg.Vcpkg.install('curl', '8.8.0')
```

You can use `installWith` to require optional features as part of the install.

```hxml
--macro hxvcpkg.Vcpkg.installWith('ffmpeg', '6.1.1', [ 'openh264' ])
```

## Configuring Vcpkg

By default vcpkg related files and artefacts will be placed in the output folder of the haxe project. To change this you can use the `hxvcpkg.Vcpkg.config` macro.

```hxml
--macro hxvcpkg.Vcpkg.config({ directory: 'C:\\My\\Custom\\Location' })
```

## Hxcpp Build Xml

Using the `xmlFile` build macro you can add hxcpp build xml data which contains knowledge of vcpkg paths.

```haxe
@:build(hxvcpkg.Vcpkg.xmlFile('Test.xml'))
class Main {}
```

```xml
<xml>

    <echo value="${VCPKG_DLL_PATH}"/>
    <echo value="${VCPKG_LIB_PATH}"/>
    <echo value="${VCPKG_INCLUDE_PATH}"/>
    <echo value="${VCPKG_TOOLS_PATH}"/>

</xml>
```

These four variables can then be used in combination with all the usual hxcpp build xml to include and link against the ports provided by vcpkg.