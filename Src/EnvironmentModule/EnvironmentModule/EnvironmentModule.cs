using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;

namespace EnvironmentModules
{
    public class EnvironmentModule : EnvironmentModuleInfo
    {
        #region Properties
        public string ModuleRoot { get; private set; }
        /// <summary>
        /// A reference counter indicating that is decreased when the module is removed and increased when loaded.
        /// </summary>
        public int ReferenceCounter { get; set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are added to the front of the environment-variable (dictionary-key) if the module is loaded. The values
        /// are removed from the environment-variable if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> PrependPaths { get; protected set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are added to the back of the environment-variable (dictionary-key) if the module is loaded. The values
        /// are removed from the environment-variable if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> AppendPaths { get; protected set; }
        /// <summary>
        /// A collection of paths (dictionary-value) that are set as environment-variable (dictionary-key) if the module is loaded. The values
        /// are deleted if unload is called.
        /// </summary>
        public Dictionary<string, List<string>> SetPaths { get; protected set; }
        /// <summary>
        /// A collection of aliases (dictionary-keys) that are set if the module is loaded. The aliases
        /// are deleted if unload is called. The value represents the command and an optional description.
        /// </summary>
        public Dictionary<string,Tuple<string,string>> Aliases { get; protected set; }
        /// <summary>
        /// A collection of aliases (dictionary-keys) that are set if the module is loaded. The aliases
        /// are deleted if unload is called. The value represents the command and an optional description.
        /// </summary>
        public Dictionary<string, System.Management.Automation.ScriptBlock> Functions { get; protected set; }

        /// <summary>
        /// This value indicates if the module was loaded by the user or as dependency of another module.
        /// </summary>
        public bool IsLoadedDirectly { get; set; }
        #endregion

        #region Constructors
        public EnvironmentModule(
            EnvironmentModuleInfo baseModule,
            string moduleRoot,
            bool isLoadedDirectly = true) : 
            base(baseModule)
        {
            ModuleRoot = moduleRoot;
            IsLoadedDirectly = isLoadedDirectly;
            PrependPaths = new Dictionary<string, List<string>>();
            AppendPaths = new Dictionary<string, List<string>>();
            SetPaths = new Dictionary<string, List<string>>();
            Aliases = new Dictionary<string, Tuple<string,string>>();
            Functions = new Dictionary<string, System.Management.Automation.ScriptBlock>();
        }
        #endregion

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

        public void AddFunction(string functionName, System.Management.Automation.ScriptBlock content)
        {
            Functions[functionName] = content;
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