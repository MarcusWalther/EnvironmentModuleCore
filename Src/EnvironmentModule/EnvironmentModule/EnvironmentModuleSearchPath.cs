namespace EnvironmentModules
{
    using System;
    using System.Runtime.Serialization;

    [KnownType(typeof(DirectorySearchPath))]
    [KnownType(typeof(RegistrySearchPath))]
    [KnownType(typeof(EnvironmentSearchPath))]
    [DataContract]
    public abstract class SearchPath : IComparable
    {
        [DataMember]
        public int Priority { get; set; }

        [DataMember]
        public string SubFolder { get; set; }

        public SearchPath(int priority, string subFolder)
        {
            Priority = priority;
            SubFolder = subFolder;
        }

        public int CompareTo(object obj)
        {
            SearchPath concreteObj = obj as SearchPath;

            if (concreteObj != null && concreteObj.Priority > Priority)
                return 1;

            return -1;
        }
    }

    [DataContract]
    public class DirectorySearchPath : SearchPath
    {
        [DataMember]
        public string Directory { get; set; }

        public DirectorySearchPath() : this("")
        {

        }

        public DirectorySearchPath(string directory, string subFolder = "", int priority = 10) : base(priority, subFolder)
        {
            Directory = directory;
        }
    }

    [DataContract]
    public class RegistrySearchPath : SearchPath
    {
        [DataMember]
        public string Key { get; set; }

        public RegistrySearchPath() : this("")
        {

        }

        public RegistrySearchPath(string key, string subFolder = "", int priority = 20) : base(priority, subFolder)
        {
            Key = key;
        }
    }

    [DataContract]
    public class EnvironmentSearchPath : SearchPath
    {
        [DataMember]
        public string Variable { get; set; }

        public EnvironmentSearchPath() : this("")
        {

        }

        public EnvironmentSearchPath(string variable, string subFolder = "", int priority = 9) : base(priority, subFolder)
        {
            Variable = variable;
        }
    }
}
