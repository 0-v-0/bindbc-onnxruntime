module bindbc.onnxruntime.v12.bind;

import bindbc.loader;
import bindbc.onnxruntime.config;
import bindbc.onnxruntime.v12.types;
import std.meta;

version (BindONNXRuntime_Static)
{
    extern (C) OrtApiBase* OrtGetApiBase();

    version (WITH_CUDA)
    {
        OrtStatus* OrtSessionOptionsAppendExecutionProvider_CPU(OrtSessionOptions* options, int use_arena);
        OrtStatus* OrtSessionOptionsAppendExecutionProvider_CUDA(OrtSessionOptions* options, int device_id);
        OrtStatus* OrtSessionOptionsAppendExecutionProvider_Tensorrt(OrtSessionOptions* options, int device_id);
    }
}
else
{
    private __gshared SharedLib lib;

extern (C) @nogc nothrow:

    __gshared {
        private ONNXRuntimeSupport loadedVersion;
        const(OrtApiBase)* function() OrtGetApiBase;
        version (WITH_CUDA)
        {
            OrtStatus* function(OrtSessionOptions* options, int use_arena) OrtSessionOptionsAppendExecutionProvider_CPU;
            OrtStatus* function(OrtSessionOptions* options, int device_id) OrtSessionOptionsAppendExecutionProvider_CUDA;
            OrtStatus* function(OrtSessionOptions* options, int device_id) OrtSessionOptionsAppendExecutionProvider_Tensorrt;
        }
    }

    ONNXRuntimeSupport loadedONNXVersion() => loadedVersion;

    bool isONNXLoaded() => lib != invalidHandle;

    ONNXRuntimeSupport loadONNXRuntime()
    {
        version (Windows)
        {
            const(char)*[1] libNames = ["onnxruntime.dll"];
        }
        else version (OSX)
        {
            const(char)*[2] libNames = [
                "libonnxruntime.dylib", "libonnxruntime.1.2.0.dylib"
            ];
        }
        else version (Posix)
        {
            const(char)*[2] libNames = ["onnxruntime.so", "onnxruntime.so.1.2"];
        }
        else
            static assert(false,
                "bindbc-onnxruntime support for ONNX Runtime 1.2 is not implemented on this platform.");

        ONNXRuntimeSupport ret;
        foreach (libName; libNames)
        {
            ret = loadONNXRuntimeByLibName(libName);
            if (ret != ONNXRuntimeSupport.noLibrary)
            {
                return ret;
            }
        }

        return ONNXRuntimeSupport.noLibrary;
    }

    ONNXRuntimeSupport loadONNXRuntimeByLibName(const char* libName)
    in (libName !is null)
    {
        lib = load(libName);
        if (lib == invalidHandle)
        {
            return ONNXRuntimeSupport.noLibrary;
        }

        const errCount = errorCount();

        lib.bindSymbol(cast(void**)&OrtGetApiBase, "OrtGetApiBase");
        version (WITH_CUDA)
        {
            foreach (alias f; AliasSeq!(
                OrtSessionOptionsAppendExecutionProvider_CPU,
                OrtSessionOptionsAppendExecutionProvider_CUDA,
                OrtSessionOptionsAppendExecutionProvider_Tensorrt))
            {
                lib.bindSymbol(cast(void**)&f, f.stringof);
            }
        }

        if (errCount != errorCount())
        {
            return ONNXRuntimeSupport.badLibrary;
        }
        loadedVersion = ONNXRuntimeSupport.onnx12;

        return ONNXRuntimeSupport.onnx12;
    }

    void unloadONNXRuntime()
    {
        if (lib != invalidHandle)
        {
            lib.unload();
        }
    }
}
