const std = @import("std");

// const allocator = std.heap.page_allocator;

// FixME: log levels don't work for build.zig during `zig build`; see ref: <https://github.com/ziglang/zig/issues/9802>
const log = std.log.scoped(.build);
pub var log_level: std.log.Level = .err;
pub const scope_levels = [_]std.log.ScopeLevel{
    .{ .scope = .build, .level = .warn },
    .{ .scope = .interpreter, .level = .info },
    .{ .scope = .linker, .level = .info },
    .{ .scope = .parser, .level = .err },
};

fn buildSimple(builder: *std.build.Builder, name: []const u8, source_path: ?[]const u8) void {
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

const WriteStep = struct {
    builder: *std.build.Builder = undefined,
    step: std.build.Step = undefined,

    data: []const u8,
    out: std.fs.File = undefined,

    // pub fn init(builder: *Builder, data: []const u8) WriteStep {
    //     return WriteStep{
    //         .builder = builder,
    //         .step = Step.init(.write, builder.fmt("log {s}", .{data}), builder.allocator, make),
    //         .data = builder.dupe(data),
    //     };
    // }

    pub fn create(b: *std.build.Builder, options: struct { data: []const u8, out: ?std.fs.File = null }) *WriteStep {
        var result = b.allocator.create(WriteStep) catch @panic("memory");
        result.*.builder = b;
        result.*.step = std.build.Step.init(.custom, "write", b.allocator, make);
        result.*.data = options.data;
        // result.*.data = b.dupe(options.data);
        result.*.out = if (options.out) |o| o else std.io.getStdOut();
        return result;
    }

    fn make(step: *std.build.Step) anyerror!void {
        const self = @fieldParentPtr(WriteStep, "step", step);
        // const s = .{self.builder};
        // const s = "s";
        // log.debug("{s}", .{self.builder});
        // _ = self.builder.fmt("log {s}", .{"test"});
        // const s = self.builder.fmt("[WriteStep] {s}", .{self.data});
        // std.log.warn("{s}", .{self.data});
        // std.io.getStdOut().writer().print(self.builder.top_level_steps) catch unreachable;
        // std.io.getStdOut().writer().print("{s}", .{s}) catch unreachable;
        self.out.writer().print("{s}", .{self.data}) catch unreachable;
    }
};

// fn addWrite(self: *Builder, comptime format: []const u8, args: anytype) *WriteStep {
//         const data = self.fmt(format, args);
//         const step = self.allocator.create(WriteStep) catch unreachable;
//         step.* = WriteStep.init(self, data);
//         return step;
//     }

fn addCustomBuildStep(b: *std.build.Builder, customStep: anytype) *@TypeOf(customStep) {
    // var allocated = self.allocator.create(@TypeOf(customStep)) catch unreachable;
    // allocated.* = customStep;
    // allocated.*.step = std.build.Step.init(.custom, @typeName(@TypeOf(customStep)), self.allocator, @TypeOf(customStep).make);
    // allocated.builder = self;
    // return allocated;
    // return *@TypeOf(customStep) {
    //     .builder = b,
    //     .step = std.build.Step.init(.custom, @typeName(@TypeOf(customStep)), b.allocator, @TypeOf(customStep).make),
    // };
    var result = b.allocator.create(@TypeOf(customStep)) catch @panic("failed allocation");
    result.* = customStep;
    result.*.step = std.build.Step.init(.custom, @typeName(@TypeOf(customStep)), b.allocator, @TypeOf(customStep).make);
    result.*.builder = b;
    return result;
}

pub fn build(b: *std.build.Builder) void {
    // // ref: <https://ziglang.org/documentation/master/#Choosing-an-Allocator>
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // var a = arena.allocator();

    // var args_it = std.process.args();
    // defer args_it.deinit();
    // while (args_it.next(a)) | arg | {
    //     log.debug("arg = {s}", .{arg});
    // }


    const fmt = b.fmt;

    // clear default top-level steps ("install" and "uninstall")
    b.top_level_steps.clearAndFree();

    // log.debug("build_root = '{s}'", .{ b.build_root });
    // log.debug("cache_root = '{s}'", .{ b.cache_root });
    // log.debug("install_prefix = '{s}'", .{ b.install_prefix });
    // log.debug("dest_dir = '{s}'", .{ b.dest_dir });
    // log.debug("exe_dir = '{s}'", .{ b.exe_dir });
    // log.debug("lib_dir = '{s}'", .{ b.lib_dir });
    // log.debug("zig_exe = '{s}'", .{ b.zig_exe });
    // log.debug("@src = '{s}'", .{ @src().file });

    // const cwd = std.fs.cwd().realpathAlloc(b.allocator, ".");
    // const p_root = std.fs.cwd().realpathAlloc(b.allocator, b.build_root);
    const cwd = std.process.getCwdAlloc(b.allocator) catch unreachable;
    const p_root = std.fs.path.resolve(b.allocator, &[_][]const u8{ cwd, b.build_root }) catch unreachable;
    const p_cache = std.fs.path.resolve(b.allocator, &[_][]const u8{ p_root, b.cache_root }) catch unreachable;
    const p_cache_rel = std.fs.path.relative(b.allocator, cwd, p_cache) catch unreachable;
    const p_install = std.fs.path.resolve(b.allocator, &[_][]const u8{ cwd, b.install_prefix }) catch unreachable;
    const p_install_rel = std.fs.path.relative(b.allocator, cwd, p_install) catch unreachable;

    // log.debug("cwd = '{s}'", .{ cwd });
    // log.debug("p_root = '{s}'", .{ p_root });
    // log.debug("p_cache = '{s}'", .{ p_cache });
    // log.debug("p_cache_rel = '{s}'", .{ p_cache_rel });
    // log.debug("p_install = '{s}'", .{ p_install });
    // log.debug("p_install_rel = '{s}'", .{ p_install_rel });

    // ToDO: handle 'repo.gh.project'? and 'PROJECT/repo...'
    const project_name = std.fs.path.basename(p_root);
    // log.debug("project_name = '{s}'", .{ project_name });

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
    // log.debug("p_exe_artifact = '{s}'", .{ p_exe_artifact });

    // build steps
    // * order is preserved when displayed by 'help'
    // * capitalized variable names are used to avoid namespace collisions with other functions or variables
    // const Build = b.step("build", std.fmt.allocPrint(allocator, "Generate project artifact(s) (stored in '{s}')", .{ b.install_prefix }) catch unreachable);
    const Build = b.step("build", fmt("Generate project artifact(s) (written to '{s}')", .{ p_install_rel }));
    const Clean = b.step("clean", fmt("Remove project artifacts (cached in '{s}')", .{ p_cache_rel }));
    // var Compile = b.step("compile", std.fmt.allocPrint(allocator, "Compile project (cached in '{s}')", .{ b.cache_root }) catch unreachable);
    const Compile = b.step("compile", fmt("Compile project (cached in '{s}')", .{ p_cache_rel }));
    const Help = b.step("help", "Display build help");
    const Run = b.step("run", fmt("Run '{s}'", .{ project_name }));

    // "build"
    Build.dependOn(&exe_install.step);

    // "clean"
    // FIXME: build step is executed from zig-cache blocking removal ; see [zig build ~ unable to clean 'zig-cache'](https://github.com/ziglang/zig/issues/9216)
    // const clean_cache = b.addRemoveDirTree(p_cache_rel);
    // clean.dependOn(&clean_cache.step);
    // ToDO: remove only if p_install is sub-directory of p_root (or maybe CWD?)
    Clean.dependOn(&b.addRemoveDirTree(p_install).step);

    // "compile"
    Compile.dependOn(&exe.step);

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
    run_cmd.step.dependOn(Build);
    Run.dependOn(&run_cmd.step);

    b.default_step = Run;

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

    // "help"
    var helpText = fmt("Usage: {s} build [STEPS..] [OPTIONS..]\n", .{ b.zig_exe });
    helpText = fmt("{s}\nSteps:\n", .{helpText});
    for (b.top_level_steps.items) |step| {
        // log.debug("{s}\t\t{s}", .{step.step.name, step.description} );
        helpText = fmt("{s}  {s:<15}{s}\n", .{helpText, step.step.name, step.description} );
    }
    helpText = fmt("{s}\nOptions:\n  {s:<15}Display additional help.", .{helpText, "-h, --help"});

    // help.dependOn(&b.addLog("{s}", .{b.top_level_steps}).step);
    // help.dependOn(addCustomBuildStep(b, WriteStep{.data = "{s}"}));
    // help.dependOn(&addCustomStep(b, WriteStep{ .data = fmt("{s}", .{b.top_level_steps}) }).step);
    // help.dependOn(&WriteStep.create(b, .{ .data = fmt("{s}", .{b.top_level_steps}) }).step);
    // help.dependOn(&WriteStep.create(b, .{ .data = helpText }).step);

    Help.dependOn(&WriteStep.create(b, .{ .data = helpText }).step);

}
