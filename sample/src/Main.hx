import sys.io.File;
import haxe.io.Bytes;
import haxe.io.BytesData;

@:build(hxvcpkg.Vcpkg.xmlFile('Curl.xml'))
@:include('Curl.hpp')
extern class Curl {
    @:native('::hx::curl::download')
    static function download(url:String):BytesData;
}

function main() {
    trace('starting download...');

    final data = Bytes.ofData(Curl.download('https://github.com'));

    trace('downloaded ${data.length} bytes');

    File.saveContent('out.txt', data.toString());
}