using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SharedLibrary.Contracts
{
    public class UserCreatedEvent
    {
        public string Name {get; set;} = null!;
        public string Email {get; set;} = null!;
    }
}