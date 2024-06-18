#pragma once

#include <hxcpp.h>
#include <vector>
#include <memory>
#include <curl/curl.h>

namespace hx
{
    namespace curl
    {
        size_t write(void* buffer, size_t size, size_t nmemb, void* baton)
        {
            auto array    = static_cast<Array_obj<uint8_t>*>(baton);
            auto realSize = size * nmemb;
            auto dst      = array->length;

            ExitGCFreeZone();

            array->EnsureSize(array->length + realSize);

            EnterGCFreeZone();

            std::memcpy(array->getBase() + dst, buffer, realSize);

            return realSize;
        }

        Array<uint8_t> download(String url)
        {
            EnterGCFreeZone();

            if (CURLE_OK != curl_global_init(CURL_GLOBAL_DEFAULT))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to init curl"));
            }

            auto curl = std::unique_ptr<CURL, void(*)(CURL*)>(curl_easy_init(), curl_easy_cleanup);
            if (!curl)
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to create curl context"));
            }
            if (CURLE_OK != curl_easy_setopt(curl.get(), CURLOPT_URL, url.utf8_str()))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to set url option"));
            }
            if (CURLE_OK != curl_easy_setopt(curl.get(), CURLOPT_FOLLOWLOCATION, 1L))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to set follow location option"));
            }
            if (CURLE_OK != curl_easy_setopt(curl.get(), CURLOPT_WRITEFUNCTION, write))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to set write function"));
            }

            ExitGCFreeZone();
            
            auto buffer = Array<uint8_t>(0, 0);

            EnterGCFreeZone();

            if (CURLE_OK != curl_easy_setopt(curl.get(), CURLOPT_WRITEDATA, buffer.mPtr))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to set write data"));
            }
            if (CURLE_OK != curl_easy_perform(curl.get()))
            {
                ExitGCFreeZone();
                Throw(HX_CSTRING("Failed to perform request"));
            }
            
            ExitGCFreeZone();

            return buffer;
        }
    }
}