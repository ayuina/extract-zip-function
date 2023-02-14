using System;
using System.Linq;
using System.IO;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Extensions.Logging;
using System.IO.Compression;
using System.Threading.Tasks;

namespace extract_zip_function
{
    public class ExtractArchive
    {
        [FunctionName("ExtractArchive")]
        [StorageAccount("DataStorage")]
        public async Task Run(
            [BlobTrigger("archive-upload/{name}", Source = BlobTriggerSource.EventGrid)] Stream myBlob, 
            string name,
            Binder binder,
            ILogger log)
        {
            log.LogInformation($"C# Blob trigger function Processed blob, Name: {name}, Size: {myBlob.Length} Bytes");
            var sw = System.Diagnostics.Stopwatch.StartNew();

            using(var zip = new ZipArchive(myBlob, ZipArchiveMode.Read))
            {
                int idx = 0;
                var prefix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
                foreach(var entry in zip.Entries)
                {
                    if(entry.FullName.EndsWith("/"))
                    {
                        log.LogDebug($"skipping entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                        continue;
                    }

                    log.LogDebug($"extracting entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                    var outputbind = new Attribute[]{
                        new BlobAttribute($"archive-extracted/{prefix}/{name}/{entry.FullName}", FileAccess.Write)
                    };
                    using(var output = await binder.BindAsync<Stream>(outputbind))
                    {
                        await entry.Open().CopyToAsync(output);
                    }
                }
            }

            sw.Stop();
            log.LogInformation($"Elapsed Time {sw.ElapsedMilliseconds} msec");
        }
    }
}
