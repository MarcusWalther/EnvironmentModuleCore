namespace EnvironmentModules
{
    using System;
    using System.Runtime.Serialization;

    [KnownType(typeof(DirectorySearchPath))]
    [KnownType(typeof(RegistrySearchPath))]
    [KnownType(typeof(EnvironmentSearchPath))]
    [KnownType(typeof(SearchPathType))]
    [DataContract]
    public abstract class SearchPath : IComparable
    {
        [DataMember]
        public string Key { get; set; }

        [DataMember]
        public bool IsDefault { get; set; }

        [DataMember]
        public SearchPathType Type { get; set; }

        [DataMember]
        public int Priority { get; set; }

        [DataMember]
        public string SubFolder { get; set; }

        public SearchPath(SearchPath other) : this(other.Key, other.Type, other.Priority, other.SubFolder, other.IsDefault)
        {
 
        }

        public SearchPath(string key, SearchPathType type, int priority, string subFolder, bool isDefault)
        {
            Key = key;
            Type = type;
            Priority = priority;
            SubFolder = subFolder;
            IsDefault = isDefault;
        }

        public SearchPathInfo ToInfo(string module)
        {
            return new SearchPathInfo(this, module);
        }

        public int CompareTo(object obj)
        {
            SearchPath concreteObj = obj as SearchPath;

            if (concreteObj != null && concreteObj.Priority > Priority)
                return 1;

            return -1;
        }

        public override bool Equals(object obj)
        {
            SearchPath other = obj as SearchPath;

            if(other == null)
            {
                return false;
            }

            return Key == other.Key && IsDefault == other.IsDefault && Type == other.Type && Priority == other.Priority && SubFolder == other.SubFolder;
        }

        // override object.GetHashCode
        public override int GetHashCode()
        {
            return Key.GetHashCode() ^ IsDefault.GetHashCode() ^ Type.GetHashCode() ^ Priority.GetHashCode() ^ SubFolder.GetHashCode();
        }
    }

    public class SearchPathInfo : SearchPath
    {
        public string Module { get; set; }

        public SearchPathInfo(SearchPath baseSearchPath, string module) : base(baseSearchPath)
        {
            Module = module;
        }

        public override string ToString()
        {
            string subPath = string.IsNullOrEmpty(SubFolder) ? "" : $" \\ {SubFolder}";
            return $"{Module} -- {Type}: {Key}{subPath} (Priority: {Priority}, Default: {IsDefault})";
        }
    }

    /// <summary>
    /// This enum is relevant in order to print the type of the search path to the powershell output
    /// </summary>
    public enum SearchPathType { DIRECTORY, ENVIRONMENT_VARIABLE, REGISTRY }

    [DataContract]
    public class DirectorySearchPath : SearchPath
    {
        public DirectorySearchPath() : this("")
        {

        }

        public DirectorySearchPath(string directory, string subFolder = "", int priority = 10, bool isDefault = true) :
            base(directory, SearchPathType.DIRECTORY, priority, subFolder, isDefault)
        {
        }
    }

    [DataContract]
    public class RegistrySearchPath : SearchPath
    {
        public RegistrySearchPath() : this("")
        {

        }

        public RegistrySearchPath(string key, string subFolder = "", int priority = 30, bool isDefault = true) :
            base(key, SearchPathType.REGISTRY, priority, subFolder, isDefault)
        {
        }
    }

    [DataContract]
    public class EnvironmentSearchPath : SearchPath
    {
        public EnvironmentSearchPath() : this("")
        {

        }

        public EnvironmentSearchPath(string variable, string subFolder = "", int priority = 20, bool isDefault = true) :
            base(variable, SearchPathType.ENVIRONMENT_VARIABLE, priority, subFolder, isDefault)
        {
        }
    }
}
