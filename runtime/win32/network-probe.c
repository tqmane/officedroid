/* SPDX-License-Identifier: MIT
 * Exercise the adapter enumeration on which the Office installer stalled. */
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <windns.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    MIB_IF_TABLE2 *table = NULL;
    IP_ADAPTER_INFO *info;
    IP_ADAPTER_ADDRESSES *adapters = NULL, *adapter;
    ULONG size = 16384, status;
    unsigned int count = 0, addresses = 0, gateways = 0, dns_servers = 0;
    DNS_RECORD *records = NULL, *record;
    setvbuf(stdout, NULL, _IONBF, 0);
    puts("GetIfTable2: begin");
    status = GetIfTable2(&table);
    printf("GetIfTable2: status=%lu\n", status);
    if (status) return 1;
    printf("Interface count=%lu\n", table->NumEntries);
    count = table->NumEntries;
    FreeMibTable(table);
    if (!count) return 1;

    puts("GetAdaptersInfo: begin");
    size = 0;
    status = GetAdaptersInfo(NULL, &size);
    if (status != ERROR_BUFFER_OVERFLOW || !size) return 1;
    info = malloc(size);
    if (!info) return 1;
    status = GetAdaptersInfo(info, &size);
    printf("GetAdaptersInfo: status=%lu size=%lu\n", status, size);
    free(info);
    if (status) return 1;

    puts("GetAdaptersAddresses: begin");
    size = 16384;
    for (unsigned int attempt = 0; attempt < 3; ++attempt) {
        free(adapters);
        adapters = malloc(size);
        if (!adapters) return 1;
        status = GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_GATEWAYS, NULL, adapters, &size);
        printf("GetAdaptersAddresses: status=%lu size=%lu\n", status, size);
        if (status != ERROR_BUFFER_OVERFLOW) break;
    }
    if (status) { free(adapters); return 1; }
    count = 0;
    for (adapter = adapters; adapter; adapter = adapter->Next) {
        IP_ADAPTER_UNICAST_ADDRESS *address;
        IP_ADAPTER_GATEWAY_ADDRESS *gateway;
        IP_ADAPTER_DNS_SERVER_ADDRESS *dns;
        ++count;
        for (address = adapter->FirstUnicastAddress; address; address = address->Next) ++addresses;
        for (gateway = adapter->FirstGatewayAddress; gateway; gateway = gateway->Next) ++gateways;
        for (dns = adapter->FirstDnsServerAddress; dns; dns = dns->Next) ++dns_servers;
    }
    free(adapters);
    printf("Adapter count=%u unicast addresses=%u gateways=%u DNS servers=%u\n", count, addresses, gateways, dns_servers);
    if (!count || !addresses || !gateways || !dns_servers) return 1;
    puts("DnsQuery_A: begin");
    status = DnsQuery_A("officeclient.microsoft.com", DNS_TYPE_A, DNS_QUERY_STANDARD, NULL, &records, NULL);
    printf("DnsQuery_A: status=%lu\n", status);
    if (status) return 1;
    count = 0;
    for (record = records; record; record = record->pNext)
        if (record->wType == DNS_TYPE_A) ++count;
    DnsRecordListFree(records, DnsFreeRecordList);
    if (!count) return 1;
    puts("NETWORK_ENUM_OK");
    return 0;
}
