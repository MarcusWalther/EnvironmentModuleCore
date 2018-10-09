using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EnvironmentModules
{
    public class EnvironmentModuleAliasInfo
    {
        public string Name { get; set; }

        public string ModuleFullName { get; set; }

        public string Definition { get; set; }

        public string Description { get; set; }

        public EnvironmentModuleAliasInfo(string name, string moduleFullName, string definition, string description)
        {
            Name = name;
            ModuleFullName = moduleFullName;
            Definition = definition;
            Description = description;
        }
    }
}
