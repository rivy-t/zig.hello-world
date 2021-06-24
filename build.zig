const std = @import("std");

// const allocator = std.heap.page_allocator;
const log = std.log.scoped(.build_zig);

pub fn buildSimple(builder: *std.build.Builder, name: []const u8, source_path: ?[]const u8) void {
    const fmt = builder.fmt;
    // Release options
    // const mode: builtin.Mode = builder.standardReleaseOptions();
    const mode = builder.standardReleaseOptions();

    // Create the executable
    const src_path = source_path orelse fmt("src/{s}.zig", .{ name });
    const exe: *std.build.LibExeObjStep = builder.addExecutable(name, src_path);

    // Link with C
    exe.linkSystemLibrary("c");

    // Set build mode to release options
    exe.setBuildMode(mode);

    // TODO: not sure what this step does.
    exe.install();

    // Create a command to run the executable
    const run_cmd: *std.build.RunStep = exe.run();

    // Make the run command depend on the generic install step?
    const builder_install_step: *std.build.Step = builder.getInstallStep();
    run_cmd.step.dependOn(builder_install_step);

    // Create a step to run?
    const run_step: *std.build.Step = builder.step(builder.fmt("run-{}", name), builder.fmt("Run the '{}' example", name));

    // Make the run step depend on the run command?
    run_step.dependOn(&run_cmd.step);
}

pub fn build(b: *std.build.Builder) void {
    const fmt = b.fmt;

    // clear default top-level steps ("install" and "uninstall")
    b.top_level_steps.clearAndFree();

    log.debug("build_root = '{s}'", .{ b.build_root });
    log.debug("cache_root = '{s}'", .{ b.cache_root });
    log.debug("install_prefix = '{s}'", .{ b.install_prefix });
    log.debug("dest_dir = '{s}'", .{ b.dest_dir });
    log.debug("exe_dir = '{s}'", .{ b.exe_dir });
    log.debug("lib_dir = '{s}'", .{ b.lib_dir });
    log.debug("zig_exe = '{s}'", .{ b.zig_exe });
    log.debug("@src = '{s}'", .{ @src().file });


    // const cwd = std.fs.cwd().realpathAlloc(b.allocator, ".");
    // const p_root = std.fs.cwd().realpathAlloc(b.allocator, b.build_root);
    const cwd = std.process.getCwdAlloc(b.allocator) catch unreachable;
    const p_root = std.fs.path.resolve(b.allocator, &[_][]const u8{ cwd, b.build_root }) catch unreachable;
    const p_cache = std.fs.path.resolve(b.allocator, &[_][]const u8{ p_root, b.cache_root }) catch unreachable;
    const p_cache_rel = std.fs.path.relative(b.allocator, cwd, p_cache) catch unreachable;
    const p_install = std.fs.path.resolve(b.allocator, &[_][]const u8{ cwd, b.install_prefix }) catch unreachable;
    const p_install_rel = std.fs.path.relative(b.allocator, cwd, p_install) catch unreachable;

    log.debug("cwd = '{s}'", .{ cwd });
    log.debug("p_root = '{s}'", .{ p_root });
    log.debug("p_cache = '{s}'", .{ p_cache });
    log.debug("p_cache_rel = '{s}'", .{ p_cache_rel });
    log.debug("p_install = '{s}'", .{ p_install });
    log.debug("p_install_rel = '{s}'", .{ p_install_rel });

    // ToDO: handle 'repo.gh.project'? and 'PROJECT/repo...'
    const project_name = std.fs.path.basename(p_root);
    log.debug("project_name = '{s}'", .{ project_name });

    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable(project_name, "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.strip = switch (mode) { .Debug => false , else => true };
    const exe_install = b.addInstallArtifact(exe);
    // exe.install();
    const p_exe_artifact = b.getInstallPath(exe_install.dest_dir, exe_install.artifact.out_filename);
    log.debug("p_exe_artifact = '{s}'", .{ p_exe_artifact });

    // "build"
    // const bld = b.step("build", std.fmt.allocPrint(allocator, "Generate project artifact(s) (stored in '{s}')", .{ b.install_prefix }) catch unreachable);
    const bld = b.step("build", fmt("Generate project artifact(s) (written to '{s}')", .{ p_install_rel }));
    bld.dependOn(&exe_install.step);

    // "clean"
    const clean = b.step("clean", fmt("Remove project artifacts (cached in '{s}')", .{ p_cache_rel }));
    // build step is executed from zig-cache blocking removal
    // const clean_cache = b.addRemoveDirTree(p_cache_rel);
    // clean.dependOn(&clean_cache.step);
    // ToDO: remove only if p_install is sub-directory of p_root (or maybe CWD?)
    clean.dependOn(&b.addRemoveDirTree(p_install).step);


    // "compile"
    // var compile = b.step("compile", std.fmt.allocPrint(allocator, "Compile project (cached in '{s}')", .{ b.cache_root }) catch unreachable);
    const compile = b.step("compile", fmt("Compile project (cached in '{s}')", .{ p_cache_rel }));
    compile.dependOn(&exe.step);

    // "help"
    const help = b.step("help", "Display build help");

    // "run"
    // const run_cmd = exe.run();
    // run_cmd.step.dependOn(&exe.step);
    // log.debug("dest_dir = '{s}'", .{ exe_install.dest_dir });
    // log.debug("out_filename = '{s}'", .{ exe_install.artifact.out_filename });
    // var run_target = std.ArrayList([]const u8).init(b.allocator);
    // defer run_target.deinit();
    // run_target.append(p_exe_artifact) catch unreachable;
    // const run_cmd = b.addSystemCommand(run_target.items);
    const run_cmd = b.addSystemCommand(&[_][]const u8{ p_exe_artifact });
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_cmd.step.dependOn(bld);
    const run = b.step("run", fmt("Run '{s}'", .{ project_name }));
    run.dependOn(&run_cmd.step);

    b.default_step = run;

    // from 'zig-examples'
    // buildSimple(builder, "all");
    // buildSimple(builder, "allocators");
    // buildSimple(builder, "booleans");
    // buildSimple(builder, "c_interop");
    // buildSimple(builder, "control_flow");
    // buildSimple(builder, "coroutines");
    // buildSimple(builder, "embed");
    // buildSimple(builder, "enums");
    // buildSimple(builder, "floats");
    // buildSimple(builder, "hello");
    // buildSimple(builder, "integers");
    // buildSimple(builder, "optionals");
    // buildSimple(builder, "random");
    // buildSimple(builder, "strings");
    // buildSimple(builder, "structs");
    // buildSimple(builder, "time");
    // buildSimple(builder, "threads");
    // buildSimple(builder, "vectors");
    // buildSimple(builder, "game");
}
