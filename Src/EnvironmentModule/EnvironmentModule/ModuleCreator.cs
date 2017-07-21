using System;
using System.Collections.Generic;
using System.IO;
using DotLiquid;

namespace EnvironmentModules
{
    public class ModuleCreator
    {
        public static void CreateMetaEnvironmentModule(string name, string rootDirectory, string defaultModule, string workingDirectory)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new EnvironmentModuleException("The name cannot be empty");
            }

            if (workingDirectory == null)
            {
                workingDirectory = Directory.GetCurrentDirectory();
            }

            if (!new DirectoryInfo(workingDirectory).Exists)
            {
                throw new EnvironmentModuleException($"The given working directory '{workingDirectory}' does not exist");
            }

            var modelDefinition = new
            {
                Author = "EnvironmentModule",
                Name = name,
                DateTime.Now.Year,
                Date            = DateTime.Now.ToString("dd/MM/yyyy"),
                Guid            = Guid.NewGuid(),
                DefaultModule   = defaultModule,
                ModuleRoot      = "\".\\\"",
                EnvironmentModuleDependencies = $"\"{defaultModule}\"",
                RequiredModules = "\"EnvironmentModules\"",
                CustomCode      = "$eModule.ModuleType = [EnvironmentModules.EnvironmentModuleType]::Meta"
            };

            FileInfo templatePsd = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psd1.template"));
            FileInfo templatePsm = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psm1.template"));

            CreateModuleFromTemplates(modelDefinition, templatePsd, templatePsm, rootDirectory, name, null, null);
        }
        
        public static void CreateEnvironmentModule(string name, string rootDirectory, string description, string workingDirectory = null, 
                                                   string author = null, string version = null, string architecture = null, 
                                                   string executable = null)
        {
            if (string.IsNullOrEmpty(name))
            {
                throw new EnvironmentModuleException("The name cannot be empty");
            }

            if (workingDirectory == null)
            {
                workingDirectory = Directory.GetCurrentDirectory();
            }

            if (!new DirectoryInfo(workingDirectory).Exists)
            {
                throw new EnvironmentModuleException($"The given working directory '{workingDirectory}' does not exist");
            }

            if (string.IsNullOrEmpty(author))
            {
                throw new EnvironmentModuleException("The author cannot be empty");
            }

            if (string.IsNullOrEmpty(description))
            {
                throw new EnvironmentModuleException("The description cannot be empty");
            }  

            FileInfo executableFile = null;
            if (!string.IsNullOrEmpty(executable))
            {
                executableFile = new FileInfo(executable);
                if (!executableFile.Exists)
                {
                    throw new EnvironmentModuleException("The executable does not exist");
                }
            }   

            var modelDefinition = new
            {
                Author = author,
                Name = name,
                Version = version,
                DateTime.Now.Year,
                Date = DateTime.Now.ToString("dd/MM/yyyy"),
                Guid = Guid.NewGuid(),
                ModuleRoot = "$null",
                FileName = executableFile?.Name ?? "",
                SearchDirectories = executableFile?.DirectoryName ?? "",
                RequiredModules = "EnvironmentModules",
                EnvironmentModuleDependencies = "",
                CustomCode = ""
            }; 

            FileInfo templatePsd = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psd1.template"));
            FileInfo templatePsm = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psm1.template"));

            CreateModuleFromTemplates(modelDefinition, templatePsd, templatePsm, rootDirectory, name, version, architecture);
        }

        private static void CreateModuleFromTemplates(object modelDefinition, FileInfo templatePsd, FileInfo templatePsm, string rootDirectory, string name, string version, string architecture)
        {
            string targetName = $"{name}{(string.IsNullOrEmpty(version) ? "" : "-" + version)}{(string.IsNullOrEmpty(architecture) ? "" : "-" + architecture)}";
            DirectoryInfo targetDirectory = new DirectoryInfo(Path.Combine(rootDirectory, targetName));

            if (targetDirectory.Exists)
            {
                throw new EnvironmentModuleException($"A directory at path {targetDirectory.FullName} does already exist");
            }

            if (!new DirectoryInfo(rootDirectory).Exists)
            {
                throw new EnvironmentModuleException("The root directory does not exist");
            }

            targetDirectory.Create();

            Dictionary<string, string> templateFiles = new Dictionary<string, string>
            {
                [templatePsd.FullName] = Path.Combine(targetDirectory.FullName, targetName + ".psd1"),
                [templatePsm.FullName] = Path.Combine(targetDirectory.FullName, targetName + ".psm1")
            };

            CreateConcreteFileFromTemplate(modelDefinition, templateFiles);
        }
        
        private static void CreateConcreteFileFromTemplate(object modelDefinition, Dictionary<string, string> templateFiles)
        {
            foreach (KeyValuePair<string, string> templateFile in templateFiles)
            {
                FileInfo templateFileInfo = new FileInfo(templateFile.Key);

                if (!templateFileInfo.Exists)
                {
                    throw new EnvironmentModuleException($"The template file '{templateFileInfo.FullName}' does not exist");
                }

                string templateContent = File.ReadAllText(templateFile.Key);
                Template template = Template.Parse(templateContent);
                string concreteContent = template.Render(Hash.FromAnonymousObject(modelDefinition));
                File.WriteAllText(templateFile.Value, concreteContent);
            }
        }
    }
}
