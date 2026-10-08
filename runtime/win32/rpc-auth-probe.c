/* SPDX-License-Identifier: MIT
 * Exercise the real authentication packages required by App-V registration. */
#define SECURITY_WIN32
#include <windows.h>
#include <rpc.h>
#include <sspi.h>
#include <stdio.h>

int main(void)
{
    static const ULONG services[] = { RPC_C_AUTHN_GSS_KERBEROS,
                                     RPC_C_AUTHN_GSS_NEGOTIATE, RPC_C_AUTHN_WINNT };
    SecPkgInfoW *packages = NULL;
    ULONG count = 0;
    SECURITY_STATUS security;

    setvbuf(stdout, NULL, _IONBF, 0);
    security = EnumerateSecurityPackagesW(&count, &packages);
    printf("EnumerateSecurityPackages: status=%#lx count=%lu\n", (ULONG)security, count);
    if (security != SEC_E_OK) return 1;
    for (unsigned int i = 0; i < sizeof(services) / sizeof(services[0]); ++i) {
        ULONG j;
        RPC_STATUS status;
        for (j = 0; j < count && packages[j].wRPCID != services[i]; ++j) {}
        if (j == count) {
            printf("Missing authentication service %lu\n", services[i]);
            FreeContextBuffer(packages);
            return 1;
        }
        status = RpcServerRegisterAuthInfoW(NULL, services[i], NULL, NULL);
        printf("RpcServerRegisterAuthInfoW: service=%lu status=%lu\n", services[i], status);
        if (status != RPC_S_OK) {
            FreeContextBuffer(packages);
            return 1;
        }
    }
    FreeContextBuffer(packages);
    if (RpcServerRegisterAuthInfoW(NULL, 600, NULL, NULL) != RPC_S_UNKNOWN_AUTHN_SERVICE)
        return 1;
    puts("RPC_AUTH_OK");
    return 0;
}
