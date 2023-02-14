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
            log.LogInformation($"C# Blob trigger function Processed blob\n Name:{name} \n Size: {myBlob.Length} Bytes");

            using(var zip = new ZipArchive(myBlob, ZipArchiveMode.Read))
            {
                int idx = 0;
                var prefix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
                foreach(var entry in zip.Entries)
                {
                    if(entry.FullName.EndsWith("/"))
                    {
                        log.LogInformation($"skipping entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                        continue;
                    }

                    log.LogInformation($"extracting entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                    var outputbind = new Attribute[]{
                        new BlobAttribute($"archive-extracted/{prefix}/{name}/{entry.FullName}", FileAccess.Write)
                    };
                    using(var output = await binder.BindAsync<Stream>(outputbind))
                    {
                        await entry.Open().CopyToAsync(output);
                    }
                }
            }
        }
    }
}
