using System;

namespace EnvironmentModules
{
    public abstract class SearchPath : IComparable
    {
        public bool IsDefault { get; private set; }

        protected int Priority { get; private set; }

        public SearchPath(bool isDefault, int priority)
        {
            IsDefault = isDefault;
            Priority = priority;

            if (!isDefault)
                Priority++;
        }

        public int CompareTo(object obj)
        {
            SearchPath concreteObj = obj as SearchPath;

            if (concreteObj != null && concreteObj.Priority > Priority)
                return 1;

            return -1;
        }
    }

    public class DirectorySearchPath : SearchPath
    {
        public string Directory { get; set; }

        public DirectorySearchPath(bool isDefault, string directory = "") : base(isDefault, 10)
        {
            Directory = directory;
        }
    }

    public class RegistrySearchPath : SearchPath
    {
        public string Key { get; set; }

        public RegistrySearchPath(bool isDefault, string key = "") : base(isDefault, 20)
        {
            Key = key;
        }
    }
}
