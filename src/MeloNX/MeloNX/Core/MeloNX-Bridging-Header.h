//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//


#ifndef MeloNX-BridgingHeader_h
#define MeloNX-BridgingHeader_h

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <Foundation/Foundation.h>
#include <setjmp.h>
#include <stdbool.h>
#include <signal.h>
#include <stdint.h>
#include "Models/Options/NativeOptions.h"

struct GameInfoC {
    long FileSize;
    char TitleName[512];
    char TitleId[32];
    char Developer[256];
    char Version[16];
    unsigned char* ImageData;
    unsigned int ImageSize;
};

struct DlcNcaListItemC {
    char Path[256];
    unsigned long long TitleId;
};

struct DlcNcaListC {
    bool success;
    unsigned int size;
    struct DlcNcaListItemC* items;
};

struct AvatarArrayC {
    int Count;
    struct AvatarInfoC* Avatars;
};

struct AvatarInfoC {
    unsigned char* ImageData;
    int ImageSize;
    char* FileName;
};



typedef void (*DataCallbackFn)(const void* data, void* userData);

typedef struct {
    void*   ptr;
    int32_t len;
} CallbackData;

void RegisterCallback(const char* name, DataCallbackFn callback, void* userData);
void UnregisterCallback(const char* name);

uint8_t InvokeCallback(const char* name, const void* data, int32_t len);

uint64_t execute_function_pointer(void* functionPtr);
uint64_t execute_guest_function_pointer(void* functionPtr, void* nativeContextPtr);

static void app_initializer(void);


typedef struct {
    sigjmp_buf buffer;
    bool isActive;
    int caughtSignal;
    siginfo_t caughtSiginfo;
} SignalJumpContext;

static inline int signal_setjmp(SignalJumpContext *ctx) {
    return sigsetjmp(ctx->buffer, 1);
}

static inline void signal_longjmp(SignalJumpContext *ctx, int val) {
    siglongjmp(ctx->buffer, val);
}

static inline SignalJumpContext signal_make_context(void) {
    SignalJumpContext ctx;
    ctx.isActive = false;
    ctx.caughtSignal = 0;
    return ctx;
}

#endif
