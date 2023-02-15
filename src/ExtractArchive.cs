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
            [BlobTrigger("%eventbase_blobtrigger_container%/{name}", Source = BlobTriggerSource.EventGrid)] Stream myBlob, 
            string name,
            Binder binder,
            ILogger log)
        {
            log.LogInformation($"Event Based Blob trigger function Processed blob, Name: {name}, Size: {myBlob.Length} Bytes");
            var sw = System.Diagnostics.Stopwatch.StartNew();

            int idx = 0;
            var prefix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
            using(var zip = new ZipArchive(myBlob, ZipArchiveMode.Read))
            {
                foreach(var entry in zip.Entries)
                {
                    if(entry.FullName.EndsWith("/"))
                    {
                        log.LogDebug($"skipping entry {idx++} : {entry.FullName}");
                        continue;
                    }

                    log.LogDebug($"extracting entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                    var outputbind = new Attribute[]{
                        new BlobAttribute($"archive-extracted/{prefix}_{name}_{entry.FullName}", FileAccess.Write)
                    };
                    using(var output = await binder.BindAsync<Stream>(outputbind))
                    {
                        await entry.Open().CopyToAsync(output);
                    }
                }
            }

            sw.Stop();
            log.LogInformation($"Extracted {idx} files from {name}. Elapsed Time {sw.ElapsedMilliseconds} msec");
        }

        [FunctionName("ExtractArchive_StandardBlobTrigger")]
        [StorageAccount("DataStorage")]
        public async Task Run2(
            [BlobTrigger("%standard_blobtrigger_container%/{name}", Source = BlobTriggerSource.LogsAndContainerScan)] Stream myBlob, 
            string name,
            Binder binder,
            ILogger log)
        {
            log.LogInformation($"Standard Blob trigger function Processed blob, Name: {name}, Size: {myBlob.Length} Bytes");
            var sw = System.Diagnostics.Stopwatch.StartNew();

            int idx = 0;
            var prefix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");
            using(var zip = new ZipArchive(myBlob, ZipArchiveMode.Read))
            {
                foreach(var entry in zip.Entries)
                {
                    if(entry.FullName.EndsWith("/"))
                    {
                        log.LogDebug($"skipping entry {idx++} : {entry.FullName}");
                        continue;
                    }

                    log.LogDebug($"extracting entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                    var outputbind = new Attribute[]{
                        new BlobAttribute($"archive-extracted/{prefix}_{name}_{entry.FullName}", FileAccess.Write)
                    };
                    using(var output = await binder.BindAsync<Stream>(outputbind))
                    {
                        await entry.Open().CopyToAsync(output);
                    }
                }
            }

            sw.Stop();
            log.LogInformation($"Extracted {idx} files from {name}. Elapsed Time {sw.ElapsedMilliseconds} msec");
        }

        //https://learn.microsoft.com/ja-jp/azure/event-grid/managed-service-identity

        [FunctionName("ExtractArchive_QueueTrigger")]
        [StorageAccount("DataStorage")]
        public async Task Run3(
            [QueueTrigger("%blob_created_queue%")] string queueMesageString,
            Binder binder,
            ILogger log)
        {
            log.LogInformation($"Queue trigger function Processed blob, Size: {queueMesageString.Length} Bytes");
            log.LogDebug(queueMesageString);
            var sw = System.Diagnostics.Stopwatch.StartNew();

            dynamic msg = Newtonsoft.Json.JsonConvert.DeserializeObject(queueMesageString);
            var uri = new Uri(msg.data.url.ToString());
            var inputPath = uri.AbsolutePath.Remove(0, 1);
            log.LogDebug($"input path {inputPath}");

            int idx = 0;
            var prefix = DateTime.UtcNow.ToString("yyyyMMdd-HHmmssfff");

            var inputbind = new Attribute[]{
                new BlobAttribute(inputPath, FileAccess.Read)
            };
            using (var input = await binder.BindAsync<Stream>(inputbind))
            using (var zip = new ZipArchive(input, ZipArchiveMode.Read))
            {
                foreach (var entry in zip.Entries)
                {
                    if (entry.FullName.EndsWith("/"))
                    {
                        log.LogDebug($"skipping entry {idx++} : {entry.FullName}");
                        continue;
                    }

                    log.LogDebug($"extracting entry {idx++} : {entry.FullName}, original {entry.Length} bytes,  compressed {entry.CompressedLength} bytes");
                    var outputbind = new Attribute[]{
                        new BlobAttribute($"archive-extracted/{prefix}_{entry.FullName}", FileAccess.Write)
                    };
                    using (var output = await binder.BindAsync<Stream>(outputbind))
                    {
                        await entry.Open().CopyToAsync(output);
                    }
                }

            }
            log.LogInformation($"Extracted {idx} files from {inputPath}. Elapsed Time {sw.ElapsedMilliseconds} msec");


        }
    }
}
