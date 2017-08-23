using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using DotLiquid;

namespace EnvironmentModules
{
    public class ModuleCreator
    {
        public static void CreateMetaEnvironmentModule(string name, 
            string rootDirectory, 
            string defaultModule, 
            string workingDirectory, 
            bool directUnload, 
            string additionalDescription,
            string[] additionalEnvironmentModules)
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

            if (additionalEnvironmentModules == null)
            {
                additionalEnvironmentModules = new string[] { };
            }

            var modelDefinition = new
            {
                Author = "EnvironmentModule",
                CompanyName = "",
                Name = name,
                DateTime.Now.Year,
                Date            = DateTime.Now.ToString("dd/MM/yyyy"),
                Guid            = Guid.NewGuid(),
                ModuleRoot      = "\".\\\"",
                RequiredModules = "\"EnvironmentModules\"",
                RequiredEnvironmentModules = $"\"{defaultModule}\"" + (additionalEnvironmentModules.Length > 0 ? additionalEnvironmentModules.Select(x => $"\"x\"").Aggregate((a, b) => a + "," + b ) : ""),
                CustomCode      = "",
                AdditionalDescription = additionalDescription,
                DirectUnload    = $"${directUnload}",
                ModuleType      = EnvironmentModuleType.Meta.ToString()
            };

            FileInfo templatePsd = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psd1.template"));
            FileInfo templatePsm = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psm1.template"));
            FileInfo templatePse = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.pse1.template"));

            CreateModuleFromTemplates(modelDefinition, templatePsd, templatePsm, templatePse, rootDirectory, name, null, null);
        }
        
        public static void CreateEnvironmentModule(string name, string rootDirectory, string description, string workingDirectory = null, 
                                                   string author = null, string version = null, string architecture = null, 
                                                   string executable = null, string[] additionalEnvironmentModules = null)
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
                author = "";
            }

            if (string.IsNullOrEmpty(description))
            {
                description = "";
            }

            if (additionalEnvironmentModules == null)
            {
                additionalEnvironmentModules = new string[] {};
            }

            FileInfo executableFile;
            if (!string.IsNullOrEmpty(executable))
            {
                executableFile = new FileInfo(executable);
                if (!executableFile.Exists)
                {
                    throw new EnvironmentModuleException("The executable does not exist");
                }
            }
            else
            {
                throw new EnvironmentModuleException("No executable given");
            }

            var modelDefinition = new
            {
                Author = author,
                CompanyName = "",
                Name = name,
                Version = version,
                DateTime.Now.Year,
                Date = DateTime.Now.ToString("dd/MM/yyyy"),
                Guid = Guid.NewGuid(),
                ModuleRoot = $"(Find-FirstFile \"{executableFile.Name}\" $MODULE_SEARCHPATHS)",
                FileName = executableFile.Name,
                SearchDirectories = $"\"{executableFile.DirectoryName}\"",
                RequiredModules = "\"EnvironmentModules\"",
                RequiredEnvironmentModules = additionalEnvironmentModules.Length > 0 ? additionalEnvironmentModules.Select(x => $"\"{x}\"").Aggregate((a, b) => a + "," + b) : "",
                AdditionalDescription = description,
                CustomCode = "",
                DirectUnload = "$false",
                ModuleType = EnvironmentModuleType.Default.ToString()
            }; 

            FileInfo templatePsd = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psd1.template"));
            FileInfo templatePsm = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.psm1.template"));
            FileInfo templatePse = new FileInfo(Path.Combine(workingDirectory, "Templates\\EnvironmentModule.pse1.template"));

            CreateModuleFromTemplates(modelDefinition, templatePsd, templatePsm, templatePse, rootDirectory, name, version, architecture);
        }

        private static void CreateModuleFromTemplates(object modelDefinition, FileInfo templatePsd, FileInfo templatePsm, FileInfo templatePse, string rootDirectory, string name, string version, string architecture)
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
                [templatePsm.FullName] = Path.Combine(targetDirectory.FullName, targetName + ".psm1"),
                [templatePse.FullName] = Path.Combine(targetDirectory.FullName, targetName + ".pse1")
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
