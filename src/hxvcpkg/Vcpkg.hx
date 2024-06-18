package hxvcpkg;

import sys.io.Process;
import haxe.macro.Expr;
import haxe.Http;
import haxe.Json;
import sys.io.File;
import haxe.Exception;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;
using haxe.macro.PositionTools;

typedef Config = {
	final ?log: Bool;
	final ?directory: String;
}

typedef LibraryConfig = {
    final version: String;
    final features: Array<String>;
}

class Vcpkg {
	static var initied: Bool = false;

	static var log: Bool = false;

	static var directory: String = null;

	static final libs:Map<String, LibraryConfig> = [];

	public static function install(library:String, version:String) {
        installWith(library, version, []);
    }

    public static function installWith(library:String, version:String, features:Array<String>) {
        libs.set(library, { version: version, features: features });

		if (!initied) {
			haxe.macro.Context.onAfterInitMacros(compile);

			initied = true;
		}
    }

    public static function config(c: Config) {
		log       = c.log ?? log;
		directory = c.directory ?? directory;
    }

	public static macro function xmlFile(file:String):Array<Field> {

		final baseDirectory    = directory ?? Path.join([ Sys.getCwd(), haxe.macro.Compiler.getOutput() ]);
		final vcpkgInstallPath = Path.join([ baseDirectory, 'vcpkg_installed', triplet() ]);
		final vcpkgDllPath     = if (haxe.macro.Context.getDefines().exists('debug')) Path.join([ vcpkgInstallPath, 'debug', 'bin' ]) else Path.join([ vcpkgInstallPath, 'bin' ]);
		final vcpkgLibPath     = if (haxe.macro.Context.getDefines().exists('debug')) Path.join([ vcpkgInstallPath, 'debug', 'lib' ]) else Path.join([ vcpkgInstallPath, 'lib' ]);
		final vcpkgToolsPath   = Path.join([ vcpkgInstallPath, 'tools' ]);
		final vcpkgIncludePath = Path.join([ vcpkgInstallPath, 'include' ]);
		final clazz            = haxe.macro.Context.getLocalClass().get();
		final sourcePath       = currentDirectory();

		final builder = new StringBuf();
		builder.add('<set name="VCPKG_DLL_PATH" value="${ vcpkgDllPath }"/>\n');
		builder.add('<set name="VCPKG_LIB_PATH" value="${ vcpkgLibPath }"/>');
		builder.add('<set name="VCPKG_INCLUDE_PATH" value="${ vcpkgIncludePath }"/>');
		builder.add('<set name="VCPKG_TOOLS_PATH" value="${ vcpkgToolsPath }"/>');
		builder.add('<include name="${ Path.join([ sourcePath, file ]) }"/>');

		clazz.meta.add(
			':buildXml',
			[ macro $v{ builder.toString() } ],
			haxe.macro.Context.currentPos());

		return null;
	}

	static function compile() {
		final baseDirectory     = directory ?? Path.join([ Sys.getCwd(), haxe.macro.Compiler.getOutput() ]);
		final vcpkgCheckoutPath = Path.join([ baseDirectory, 'vcpkg' ]);
		final vcpkgInstallPath  = Path.join([ baseDirectory, 'vcpkg_installed' ]);

		if (log) {
			haxe.macro.Context.info('vcpkg checkout path : $vcpkgCheckoutPath', haxe.macro.Context.currentPos());
			haxe.macro.Context.info('vcpkg install path  : $vcpkgInstallPath', haxe.macro.Context.currentPos());
		}

		if (!FileSystem.exists(vcpkgCheckoutPath)) {

			FileSystem.createDirectory(vcpkgCheckoutPath);

			if (log) {
				haxe.macro.Context.info('Cloning vcpkg', haxe.macro.Context.currentPos());
			}

			Sys.command('git', [ 'clone', 'https://github.com/microsoft/vcpkg', vcpkgCheckoutPath ]);
		}

		if (!FileSystem.exists(vcpkgInstallPath)) {
			FileSystem.createDirectory(vcpkgInstallPath);
		}

		if (!FileSystem.exists(Path.join([ vcpkgCheckoutPath, exe() ]))) {
			if (log) {
				haxe.macro.Context.info('Bootstrapping vcpkg', haxe.macro.Context.currentPos());
			}

			if (0 != Sys.command(Path.join([ vcpkgCheckoutPath, bootstrap() ]))) {
				haxe.macro.Context.error('Failed to bootstrap vcpkg', haxe.macro.Context.currentPos());
			}
		}

		if (log) {
			haxe.macro.Context.info('Generating manifest', haxe.macro.Context.currentPos());
		}

		final manifest = {
			dependencies : [ for (lib => config in libs) { name: lib, features: config.features } ],
			overrides    : [ for (lib => config in libs) { name: lib, version: config.version } ]
		}

		File.saveContent(Path.join([ baseDirectory, 'vcpkg.json' ]), Json.stringify(manifest));

		if (log) {
			haxe.macro.Context.info('Compiling', haxe.macro.Context.currentPos());
		}

		if (0 != Sys.command(Path.join([ vcpkgCheckoutPath, 'vcpkg' ]), [ 'x-update-baseline', '--x-manifest-root', baseDirectory, '--add-initial-baseline' ])) {
			haxe.macro.Context.error('Failed to update baseline', haxe.macro.Context.currentPos());
		}
		if (0 != Sys.command(Path.join([ vcpkgCheckoutPath, 'vcpkg' ]), [ 'install', '--x-manifest-root', baseDirectory, '--x-install-root', vcpkgInstallPath, '--triplet', triplet() ])) {
			haxe.macro.Context.error('Failed to install from manifest', haxe.macro.Context.currentPos());
		}
	}

	static function currentDirectory() {
		final pos = haxe.macro.Context.currentPos().getInfos();
		final dir = Path.directory(pos.file);

		return
			if (Path.isAbsolute(dir)) {
				Path.normalize(dir);
			} else {
				Path.normalize(Path.join([ Sys.getCwd(), dir ]));
			}
	}

	static function triplet() {
		return switch Sys.systemName() {
			case 'Windows':
				'x64-windows';
			case 'Mac':
				final proc    = new Process('machine');
				final machine = switch proc.exitCode() {
					case 0:
						proc.stdout.readAll().toString();
					case _:
						throw new Exception('Failed to find machine type');
				}

				if (machine.startsWith('arm64')) {
					'arm64-osx';
				} else {
					'x64-osx';
				}
			case 'Linux':
				'x64-linux';
			case other:
				throw new Exception('Unsupported system $other');
		}
	}

	static function exe() {
		return switch Sys.systemName() {
			case 'Windows':
				'vcpkg.exe';
			case _:
				'vcpkg';
		}
	}

	static function bootstrap() {
		return switch Sys.systemName() {
			case 'Windows':
				'bootstrap-vcpkg.bat';
			case _:
				'bootstrap-vcpkg.sh';
		}
	}
}