using System;
using System.Collections.Generic;

namespace EnvironmentModules
{
    public enum EnvironmentModuleType { Default, Meta }

    public class EnvironmentModuleBase
    {
        /// <summary>
        /// The name of the module. This name can be used to load the module with the help of the powershell-environment.
        /// </summary>
        public string Name { get; }

        /// <summary>
        /// The version of the application or library.
        /// </summary>
        public string Version { get; }

        /// <summary>
        /// The machine code of the module (e.g. x86, x64, arm...).
        /// </summary>
        public string Architecture { get; }

        /// <summary>
        /// Additional infos like compiler or compilation flags (e.g. MSVC15, gcc, ...).
        /// </summary>
        public string AdditionalInfo { get; }

        /// <summary>
        /// Specifies the type of the module.
        /// </summary>
        public EnvironmentModuleType ModuleType { get; set; }

        /// <summary>
        /// All environment modules that must be loaded prior this module can be used.
        /// </summary>
        public string[] RequiredEnvironmentModules { get; set; }

        /// <summary>
        /// This value indicates whether the module should be unloaded after the import, so that just the dependencies will remain.
        /// </summary>
        public bool DirectUnload { get; set; }

        /// <summary>
        /// An additional description that is shown when the module is loaded
        /// </summary>
        public string AdditionalDescription { get; set; }


        public EnvironmentModuleBase(
            string name, 
            string version, 
            string architecture, 
            string additionalInfo = "", 
            EnvironmentModuleType moduleType = EnvironmentModuleType.Default, 
            string[] requiredEnvironmentModules = null, 
            string additionalDescription = "",
            bool directUnload = false)
        {
            Name = name;
            Version = version;
            Architecture = architecture;
            AdditionalInfo = additionalInfo;
            ModuleType = moduleType;
            AdditionalDescription = additionalDescription;
            DirectUnload = directUnload;

            RequiredEnvironmentModules = requiredEnvironmentModules ?? new string[0];
        }
    }

    public class EnvironmentModule : EnvironmentModuleBase
    {
        #region Properties

        /// <summary>
        /// This value is set to 'true' if the Load-function was called and 'false' if the Unload-function was called.
        /// </summary>
        public bool IsLoaded { get; private set; }
        /// <summary>
        /// A reference counter indicating that is decreased when the module is removed and increased when loaded.
        /// </summary>
        public int ReferenceCounter { get; set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are added to the front of the environment-variable (dictionary-key) if the module is loaded. The values
        /// are removed from the environment-variable if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> PrependPaths { get; set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are added to the back of the environment-variable (dictionary-key) if the module is loaded. The values
        /// are removed from the environment-variable if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> AppendPaths { get; set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are set as environment-variable (dictionary-key) if the module is loaded. The values
        /// are deleted if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> SetPaths { get; set; }
        /// <summary>
        /// A collection of aliases (dictionary-keys) that are set if the module is loaded. The aliases
        /// are deleted if unload is called. The value represents the command and an optional description.
        /// </summary>
        public Dictionary<string,Tuple<string,string>> Aliases { get; }

        /// <summary>
        /// This value indicates if the module was loaded by the user or as dependency of another module.
        /// </summary>
        public bool IsLoadedDirectly { get; set; }
        #endregion

        #region Events
        public delegate void LoadedEventHandler(object sender, string moduleName);
        public event LoadedEventHandler LoadedEvent;
        public delegate void UnloadedEventHandler(object sender, string moduleName);
        public event UnloadedEventHandler UnloadedEvent;
        #endregion

        #region Constructors
        public EnvironmentModule(
            string name, 
            string version, 
            string architecture, 
            string additionalInfo = "", 
            EnvironmentModuleType moduleType = EnvironmentModuleType.Default, 
            string[] requiredEnvironmentModules = null,
            string additionalDescription = "",
            bool directUnload = false,
            int referenceCounter = 1, 
            bool isLoadedDirectly = true) : 
            base(name, version, architecture, additionalInfo, moduleType, requiredEnvironmentModules, additionalDescription, directUnload)
        {

            IsLoaded = false;
            ReferenceCounter = referenceCounter;
            ModuleType = moduleType;
            IsLoadedDirectly = isLoadedDirectly;
            PrependPaths = new Dictionary<string, List<string>>();
            AppendPaths = new Dictionary<string, List<string>>();
            SetPaths = new Dictionary<string, List<string>>();
            Aliases = new Dictionary<string, Tuple<string,string>>();
        } 
        #endregion

        public void Load()
        {
            IsLoaded = true;
            LoadedEvent?.Invoke(this, Name);
        }

        public void Unload()
        {
            IsLoaded = false;
            UnloadedEvent?.Invoke(this, Name);
        }

        public void AddPrependPath(string envVar, string path)
        {
            if (!PrependPaths.ContainsKey(envVar))
                PrependPaths[envVar] = new List<string>();

            PrependPaths[envVar].Add(path);
        }

        public void AddAppendPath(string envVar, string path)
        {
            if (!AppendPaths.ContainsKey(envVar))
                AppendPaths[envVar] = new List<string>();

            AppendPaths[envVar].Add(path);
        }

        public void AddSetPath(string envVar, string path)
        {
            if (!SetPaths.ContainsKey(envVar))
                SetPaths[envVar] = new List<string>();

            SetPaths[envVar].Add(path);
        }

        public void AddAlias(string aliasName, string command, string description="")
        {
            Aliases[aliasName] = new Tuple<string, string>(command,description);
        }

        public override bool Equals(object obj)
        {
            if (!(obj is EnvironmentModule))
                return false;

            EnvironmentModule em = (EnvironmentModule) obj;
            return (Name == em.Name) && (Version == em.Version) && (Architecture == em.Architecture);
        }

        public override int GetHashCode()
        {
            return Name.GetHashCode();
        }

        public override string ToString()
        {
            return Name;
        }
    }
}