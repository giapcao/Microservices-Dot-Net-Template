using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Application.Guests.Commands;
using AutoMapper;
using Domain.Entities;
using Domain.Repositories;
using MassTransit;
using SharedLibrary.Contracts.UserCreating;
using MediatR;
using SharedLibrary.Common.Commands;

namespace Application.Consumers
{
    public class UserCreatedConsumer : IConsumer<UserCreatedEvent>
    {
        private readonly IGuestRepository _guestRepository;
        private readonly IMapper _mapper;
        private readonly ISender _sender;

        public UserCreatedConsumer(IGuestRepository guestRepository, IMapper mapper, ISender sender)
        {
            _guestRepository = guestRepository;
            _mapper = mapper;
            _sender = sender;
        }
        public async Task Consume(ConsumeContext<UserCreatedEvent> context)
        {
            try
            {
                var command = new CreateGuestCommand(context.Message.Name, context.Message.Email);
                await _guestRepository.AddAsync(_mapper.Map<Guest>(command), context.CancellationToken);
                var saveResult = await _sender.Send(new SaveChangesCommand(), context.CancellationToken);
                if (saveResult.IsFailure)
                {
                    throw new Exception($"Failed to save changes: {saveResult.Error}");
                }
                await context.Publish(new GuestCreatedEvent
                {
                    CorrelationId = context.Message.CorrelationId
                });
            }catch(Exception ex){
                await context.Publish(new GuestCreatedFailureEvent
                {
                    CorrelationId = context.Message.CorrelationId,
                    Reason = ex.Message
                });
            }
        }
    }
}