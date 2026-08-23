#pragma clang diagnostic push
#if defined(__clang__) && (__clang_major__ >= 19)
#pragma clang diagnostic ignored "-Wcast-function-type-mismatch"
#endif

#define PY_SSIZE_T_CLEAN

#include <Python.h>
#include <structmember.h>
#include <liburing.h>

#include "python_api/loop/loop.h"
#include "python_api/ops/files/files.h"
#include "python_api/ops/sockets/sockets.h"
#include "python_api/timer/timer.h"
#include "python_api/execution_context/execution_context.h"


PyMODINIT_FUNC
PyInit_uringio(void);

static PyMethodDef uringio_module_methods[] = {
    {"timer", (PyCFunction)UringioLoop_timer, METH_VARARGS | METH_KEYWORDS, "Sets a timer"},
    {"open_file", (PyCFunction)Uringio_open, METH_VARARGS | METH_KEYWORDS, "Opens file and instantiate File object"},
    {"prep_socket",
     (PyCFunction)Uringio_prep_socket,
     METH_VARARGS | METH_KEYWORDS,
     "Opens socket and instantiate Socket object"},
    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_loop_methods[] = {
    {"close", (PyCFunction)UringioLoop_close, METH_VARARGS, "Close loop"},
    {"buffer_mode",
     (PyCFunction)UringioLoop_buffer_mode,
     METH_VARARGS | METH_KEYWORDS,
     "Init context to run loop with specific buffer mode"},
    {"stream_strategy",
     (PyCFunction)UringioLoop_stream_strategy,
     METH_VARARGS | METH_KEYWORDS,
     "Init context to run loop with specific stream strategy"},
    {"transfer_mode",
     (PyCFunction)UringioLoop_transfer_mode,
     METH_VARARGS | METH_KEYWORDS,
     "Init context to run loop with specific transfer mode"},
    {"execution_context",
     (PyCFunction)UringioLoop_execution_context,
     METH_VARARGS | METH_KEYWORDS,
     "Init context to run loop with specific execution context settings"},

    {"_run_once", (PyCFunction)UringioLoop_run_once, METH_NOARGS, "Run one full iteration of the event loop"},
    {"_write_to_self",
     (PyCFunction)UringioLoop_write_to_self,
     METH_NOARGS,
     "Write a byte to self-pipe, to wake up the event loop"},
    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_socket_methods[] = {
    {"bind", (PyCFunction)UringioSocket_bind, METH_VARARGS | METH_KEYWORDS, "Bind socket"},
    {"connect", (PyCFunction)UringioSocket_connect, METH_VARARGS | METH_KEYWORDS, "Connect"},
    {"listen", (PyCFunction)UringioSocket_listen, METH_VARARGS | METH_KEYWORDS, "Listen socket"},
    {"accept", (PyCFunction)UringioSocket_accept, METH_VARARGS | METH_KEYWORDS, "Accept"},
    {"close", (PyCFunction)UringioSocket_close, METH_VARARGS | METH_KEYWORDS, "Close"},
    {"send", (PyCFunction)UringioSocket_send, METH_VARARGS | METH_KEYWORDS, "Send"},
    {"recv", (PyCFunction)UringioSocket_recv, METH_VARARGS | METH_KEYWORDS, "Recv"},
    {"sendto", (PyCFunction)UringioSocket_sendto, METH_VARARGS | METH_KEYWORDS, "Sendto"},
    {"recvfrom", (PyCFunction)UringioSocket_recvfrom, METH_VARARGS | METH_KEYWORDS, "Recvfrom"},
    {"sendmsg", (PyCFunction)UringioSocket_sendmsg, METH_VARARGS | METH_KEYWORDS, "Sendmsg"},
    {"recvmsg", (PyCFunction)UringioSocket_recvmsg, METH_VARARGS | METH_KEYWORDS, "Recvmsg"},

    {"__aenter__", (PyCFunction)UringioSocket_aenter, METH_NOARGS, "Entering async context manager"},
    {"__aexit__", (PyCFunction)UringioSocket_aexit, METH_VARARGS | METH_KEYWORDS, "Closing async context manager"},
    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_file_methods[] = {
    {"read", (PyCFunction)UringioFile_read, METH_VARARGS | METH_KEYWORDS, "Read file"},
    {"readv", (PyCFunction)UringioFile_readv, METH_VARARGS | METH_KEYWORDS, "Read file, vectorized"},
    {"readv_raw",
     (PyCFunction)UringioFile_readv_raw,
     METH_VARARGS | METH_KEYWORDS,
     "Read file, vectorized with custom iovecs"},
    {"write", (PyCFunction)UringioFile_write, METH_VARARGS | METH_KEYWORDS, "Write file"},
    {"writev", (PyCFunction)UringioFile_writev, METH_VARARGS | METH_KEYWORDS, "Write file, vectorized"},
    {"writev_raw",
     (PyCFunction)UringioFile_writev_raw,
     METH_VARARGS | METH_KEYWORDS,
     "Write file, vectorized with custom iovecs"},
    {"close", (PyCFunction)UringioFile_close, METH_VARARGS | METH_KEYWORDS, "Close file"},
    {"fsync", (PyCFunction)UringioFile_fsync, METH_VARARGS | METH_KEYWORDS, "Flush file buffer to file"},
    {"fdatasync",
     (PyCFunction)UringioFile_fdatasync,
     METH_VARARGS | METH_KEYWORDS,
     "Flush file buffer to file with in fdatasync mode"},
    {"splice", (PyCFunction)UringioFile_splice, METH_VARARGS | METH_KEYWORDS, "Splicing two file pipes"},

    {"__aenter__", (PyCFunction)UringioFile_aenter, METH_NOARGS, "Entering async context manager"},
    {"__aexit__", (PyCFunction)UringioFile_aexit, METH_VARARGS | METH_KEYWORDS, "Closing async context manager"},
    {NULL, NULL, 0, NULL}
};

static PyMemberDef uringio_file_members[] = {
    {
        .name = "fd",
        .type = Py_T_INT,
        .offset = offsetof(UringioFile, fd),
        .flags = READONLY,
        .doc = "file descriptor",
    },
    {0},
};

static PyMethodDef uringio_buffer_mode_ctx_methods[] = {
    {"__enter__", (PyCFunction)BufferModeCtx_enter, METH_NOARGS, "Entering context manager"},
    {"__exit__", (PyCFunction)BufferModeCtx_exit, METH_VARARGS, "Closing context manager"},

    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_stream_strategy_ctx_methods[] = {
    {"__enter__", (PyCFunction)StreamStrategyCtx_enter, METH_NOARGS, "Entering context manager"},
    {"__exit__", (PyCFunction)StreamStrategyCtx_exit, METH_VARARGS, "Closing context manager"},

    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_transfer_mode_ctx_methods[] = {
    {"__enter__", (PyCFunction)TransferModeCtx_enter, METH_NOARGS, "Entering context manager"},
    {"__exit__", (PyCFunction)TransferModeCtx_exit, METH_VARARGS, "Closing context manager"},

    {NULL, NULL, 0, NULL}
};

static PyMethodDef uringio_execution_context_ctx_methods[] = {
    {"__enter__", (PyCFunction)ExecutionContextCtx_enter, METH_NOARGS, "Entering context manager"},
    {"__exit__", (PyCFunction)ExecutionContextCtx_exit, METH_VARARGS, "Closing context manager"},

    {NULL, NULL, 0, NULL}
};

PyTypeObject *UringioLoopType = NULL;

static PyType_Slot UringioLoop_slots[] = {
    {Py_tp_doc, (void *)PyDoc_STR("Rings with python loop")},
    {Py_tp_new, UringioLoop_new},
    {Py_tp_init, UringioLoop_init},
    {Py_tp_dealloc, UringioLoop_dealloc},
    {Py_tp_traverse, UringioLoop_traverse},
    {Py_tp_clear, UringioLoop_clear},
    {Py_tp_methods, uringio_loop_methods},
    {0, NULL}
};

static PyType_Spec UringioLoop_spec = {
    .name = "uringio.UringioLoop",
    .basicsize = sizeof(UringioLoop),
    .itemsize = 0,
    .flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
    .slots = UringioLoop_slots,
};

PyTypeObject UringioFileType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.File",
    .tp_doc = PyDoc_STR("uringio file adapter"),
    .tp_basicsize = sizeof(UringioFile),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_traverse = (traverseproc)UringioFile_traverse,
    .tp_clear = (inquiry)UringioFile_clear,
    .tp_dealloc = (destructor)UringioFile_dealloc,
    .tp_methods = uringio_file_methods,
    .tp_members = uringio_file_members,
};

PyTypeObject UringioSocketType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.Socket",
    .tp_doc = PyDoc_STR("uringio socket adapter"),
    .tp_basicsize = sizeof(UringioSocket),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_GC,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_traverse = (traverseproc)UringioSocket_traverse,
    .tp_clear = (inquiry)UringioSocket_clear,
    .tp_dealloc = (destructor)UringioSocket_dealloc,
    .tp_methods = uringio_socket_methods,
};

PyTypeObject UringioBufferModeCtxType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.BufferModeCtx",
    .tp_doc = PyDoc_STR("Buffer Mode helper for context manager"),
    .tp_basicsize = sizeof(BufferModeCtx),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_dealloc = (destructor)BufferModeCtx_dealloc,
    .tp_methods = uringio_buffer_mode_ctx_methods,
};

PyTypeObject UringioStreamStrategyCtxType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.StreamStrategyCtx",
    .tp_doc = PyDoc_STR("Stream Strategy helper for context manager"),
    .tp_basicsize = sizeof(StreamStrategyCtx),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_dealloc = (destructor)StreamStrategyCtx_dealloc,
    .tp_methods = uringio_stream_strategy_ctx_methods,
};

PyTypeObject UringioTransferModeCtxType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.TransferModeCtx",
    .tp_doc = PyDoc_STR("Transfer Mode helper for context manager"),
    .tp_basicsize = sizeof(TransferModeCtx),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_dealloc = (destructor)TransferModeCtx_dealloc,
    .tp_methods = uringio_transfer_mode_ctx_methods,
};

PyTypeObject UringioExecutionContextCtxType = {
    .ob_base = PyVarObject_HEAD_INIT(NULL, 0).tp_name = "uringio.ExecutionContextCtx",
    .tp_doc = PyDoc_STR("Execution Context helper for context manager"),
    .tp_basicsize = sizeof(ExecutionContextCtx),
    .tp_itemsize = 0,
    .tp_flags = Py_TPFLAGS_DEFAULT,
    .tp_new = PyType_GenericNew,
    .tp_init = NULL,
    .tp_dealloc = (destructor)ExecutionContextCtx_dealloc,
    .tp_methods = uringio_execution_context_ctx_methods,
};

static int
uringio_module_exec(PyObject *m) {
    PyObject *asyncio = PyImport_ImportModule("asyncio");
    if (!asyncio)
        return -1;

    PyObject *base = PyObject_GetAttrString(asyncio, "BaseEventLoop");
    Py_DECREF(asyncio);
    if (!base)
        return -1;

    PyObject *bases = PyTuple_Pack(1, base);
    Py_DECREF(base);
    if (!bases)
        return -1;

    PyObject *type = PyType_FromSpecWithBases(&UringioLoop_spec, bases);
    Py_DECREF(bases);
    if (!type)
        return -1;

    UringioLoopType = (PyTypeObject *)type;

    if (PyType_Ready(&UringioSocketType) < 0)
        return -1;

    if (PyType_Ready(&UringioFileType) < 0)
        return -1;

    if (PyType_Ready(&UringioBufferModeCtxType) < 0)
        return -1;

    if (PyType_Ready(&UringioStreamStrategyCtxType) < 0)
        return -1;

    if (PyType_Ready(&UringioTransferModeCtxType) < 0)
        return -1;

    if (PyType_Ready(&UringioExecutionContextCtxType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "UringioLoop", type) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "File", (PyObject *)&UringioFileType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "Socket", (PyObject *)&UringioSocketType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "BufferModeCtx", (PyObject *)&UringioBufferModeCtxType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "StreamStrategyCtx", (PyObject *)&UringioStreamStrategyCtxType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "TransferModeCtx", (PyObject *)&UringioTransferModeCtxType) < 0)
        return -1;

    if (PyModule_AddObjectRef(m, "ExecutionContextCtx", (PyObject *)&UringioExecutionContextCtxType) < 0)
        return -1;

    PyObject *resolve_flags = create_resolve_enum();
    if (!resolve_flags)
        return -1;

    if (PyModule_AddObject(m, "ResolveFlags", resolve_flags) < 0) {
        Py_DECREF(resolve_flags);
        return -1;
    }

    PyObject *statx_flags = create_statx_flags_enum();
    if (!statx_flags)
        return -1;

    if (PyModule_AddObject(m, "StatxFlags", statx_flags) < 0) {
        Py_DECREF(statx_flags);
        return -1;
    }

    PyObject *statx_mask = create_statx_mask_enum();
    if (!statx_mask)
        return -1;

    if (PyModule_AddObject(m, "StatxMask", statx_mask) < 0) {
        Py_DECREF(statx_mask);
        return -1;
    }

    PyObject *buffer_mode = create_buffer_mode_enum();
    if (!buffer_mode)
        return -1;

    if (PyModule_AddObject(m, "BUFFER_MODE", buffer_mode) < 0) {
        Py_DECREF(buffer_mode);
        return -1;
    }

    PyObject *stream_strategy = create_stream_strategy_enum();
    if (!stream_strategy)
        return -1;

    if (PyModule_AddObject(m, "STREAM_STRATEGY", stream_strategy) < 0) {
        Py_DECREF(stream_strategy);
        return -1;
    }

    PyObject *transfer_mode = create_transfer_mode_enum();
    if (!transfer_mode)
        return -1;

    if (PyModule_AddObject(m, "TRANSFER_MODE", transfer_mode) < 0) {
        Py_DECREF(transfer_mode);
        return -1;
    }

    PyObject *payload_type = create_payload_type_enum();
    if (!payload_type)
        return -1;

    if (PyModule_AddObject(m, "PAYLOAD_TYPE", payload_type) < 0) {
        Py_DECREF(payload_type);
        return -1;
    }
    return 0;
}

static PyModuleDef_Slot uringio_module_slots[] = {
    {Py_mod_exec, uringio_module_exec},
    {Py_mod_multiple_interpreters, Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED},
    {0, NULL}
};

static PyModuleDef uringio_module = {
    .m_base = PyModuleDef_HEAD_INIT,
    .m_name = "uringio",
    .m_doc = "Module contains uring based loop",
    .m_size = 0,
    .m_methods = uringio_module_methods,
    .m_slots = uringio_module_slots,
};

PyMODINIT_FUNC
PyInit_uringio(void) // cppcheck-suppress unusedFunction
{
    return PyModuleDef_Init(&uringio_module);
}
